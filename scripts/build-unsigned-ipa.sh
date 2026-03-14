#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${PROJECT_PATH:-Tyflocentrum.xcodeproj}"
SCHEME="${SCHEME:-Tyflocentrum}"
SWIFTFORMAT_VERSION="${SWIFTFORMAT_VERSION:-0.58.7}"
SIM_DESTINATION="${SIM_DESTINATION:-}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${RUNNER_TEMP:-$PWD}/DerivedData-${GITHUB_RUN_ID:-local}}"
RUN_TESTS="${RUN_TESTS:-true}"
RUN_ARCHIVE="${RUN_ARCHIVE:-true}"

ensure_swiftformat() {
	if command -v swiftformat >/dev/null 2>&1; then
		return
	fi

	if command -v brew >/dev/null 2>&1; then
		brew install swiftformat
		return
	fi

	local tool_cache="${RUNNER_TOOL_CACHE:-$PWD/.tool-cache}"
	local swiftformat_dir="$tool_cache/swiftformat/$SWIFTFORMAT_VERSION"
	local swiftformat_bin="$swiftformat_dir/swiftformat"

	if [[ ! -x "$swiftformat_bin" ]]; then
		mkdir -p "$swiftformat_dir"

		local tmp_dir
		tmp_dir="$(mktemp -d)"

		local url="https://github.com/nicklockwood/SwiftFormat/releases/download/$SWIFTFORMAT_VERSION/swiftformat.zip"
		curl -fsSL -o "$tmp_dir/swiftformat.zip" "$url"
		/usr/bin/unzip -q "$tmp_dir/swiftformat.zip" -d "$swiftformat_dir"
		chmod +x "$swiftformat_bin"
		rm -rf "$tmp_dir"
	fi

	export PATH="$swiftformat_dir:$PATH"
}

resolve_sim_destination() {
	if [[ -n "$SIM_DESTINATION" ]]; then
		return
	fi

	local sim_info
	sim_info="$(
		xcrun simctl list devices available | awk '
			$1 == "--" && $2 == "iOS" {
				ios = $3
				next
			}
			$1 == "--" {
				ios = ""
				next
			}
				ios == "" {
					next
				}
				$1 == "iPhone" {
					line = $0
					sub(/^[ \t]+/, "", line)

					name = line
					sub(/ [(].*/, "", name)

					if (!match(line, /[(][0-9A-Fa-f-]+[)]/)) {
						next
					}
					id = substr(line, RSTART + 1, RLENGTH - 2)
					if (first_id[ios] == "") {
						first_id[ios] = id
						first_name[ios] = name
					}
				}
				END {
					best_any = ""
					best_any_weight = -1
					best_stable = ""
					best_stable_weight = -1

					for (v in first_id) {
						w = ver_weight(v)
						if (w > best_any_weight) {
							best_any_weight = w
							best_any = v
						}

						split(v, parts, ".")
						major = parts[1] + 0
						if (major < 20 && w > best_stable_weight) {
							best_stable_weight = w
							best_stable = v
						}
					}

					if (best_stable != "") {
						best = best_stable
					} else {
						best = best_any
					}

					if (best == "" || first_id[best] == "") {
						exit 1
					}

					printf "%s\t%s\t%s\n", best, first_id[best], first_name[best]
				}
				function ver_weight(v, parts, n, major, minor, patch) {
					n = split(v, parts, ".")
					major = parts[1] + 0
					minor = (n >= 2 ? parts[2] + 0 : 0)
					patch = (n >= 3 ? parts[3] + 0 : 0)
					return major * 1000000 + minor * 1000 + patch
				}
			' || true
		)"

	if [[ -z "$sim_info" ]]; then
		echo "No available iPhone simulators found. Set SIM_DESTINATION env var (e.g. platform=iOS Simulator,name=iPhone 15)." >&2
		xcrun simctl list devices available || true
		exit 1
	fi

	local sim_os sim_id sim_name
	IFS=$'\t' read -r sim_os sim_id sim_name <<<"$sim_info"

	if [[ -z "${sim_id:-}" ]]; then
		echo "Failed to parse a simulator device ID from simctl output. Set SIM_DESTINATION env var." >&2
		xcrun simctl list devices available || true
		exit 1
	fi

	echo "Using simulator: $sim_name (iOS $sim_os) [$sim_id]"
	SIM_DESTINATION="platform=iOS Simulator,id=$sim_id"
}

echo "::group::Xcode version"
xcodebuild -version
echo "::endgroup::"

echo "::group::SwiftFormat (lint)"
ensure_swiftformat
swiftformat --config .swiftformat --lint .
echo "::endgroup::"

rm -rf "$DERIVED_DATA_PATH"

if [[ "$RUN_TESTS" == "true" ]]; then
	echo "::group::Test (Simulator)"
	resolve_sim_destination
	xcodebuild \
		-project "$PROJECT_PATH" \
		-scheme "$SCHEME" \
		-configuration Debug \
		-sdk iphonesimulator \
		-destination "$SIM_DESTINATION" \
		-derivedDataPath "$DERIVED_DATA_PATH" \
		-parallel-testing-enabled NO \
		-parallel-testing-worker-count 1 \
		test
	echo "::endgroup::"
fi

if [[ "$RUN_ARCHIVE" == "true" ]]; then
	echo "::group::Archive (no codesign)"
	rm -rf build
	xcodebuild \
		-project "$PROJECT_PATH" \
		-scheme "$SCHEME" \
		-configuration Release \
		-sdk iphoneos \
		-destination 'generic/platform=iOS' \
		-archivePath build/Tyflocentrum.xcarchive \
		-derivedDataPath "$DERIVED_DATA_PATH" \
		archive \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY=""
	echo "::endgroup::"

	echo "::group::Create unsigned IPA"
	rm -rf Payload tyflocentrum.ipa
	mkdir -p Payload
	cp -R build/Tyflocentrum.xcarchive/Products/Applications/*.app Payload/
	/usr/bin/zip -r tyflocentrum.ipa Payload
	echo "::endgroup::"

	ls -lh tyflocentrum.ipa
fi
