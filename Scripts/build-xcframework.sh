#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_directory="${1:-${repository_root}/.build/xcframework-output}"
work_directory="${repository_root}/.build/xcframework-work"
device_archive="${work_directory}/MBIssueKit-iOS.xcarchive"
simulator_archive="${work_directory}/MBIssueKit-Simulator.xcarchive"
device_derived_data="${work_directory}/DerivedData-iOS"
simulator_derived_data="${work_directory}/DerivedData-Simulator"
xcframework_path="${output_directory}/MBIssueKit.xcframework"
zip_path="${output_directory}/MBIssueKit.xcframework.zip"

if [[ -e "${output_directory}" ]]; then
    echo "Output directory already exists: ${output_directory}" >&2
    exit 1
fi

rm -rf "${work_directory}"
mkdir -p "${work_directory}" "${output_directory}"

archive() {
    local destination="$1"
    local archive_path="$2"
    local derived_data_path="$3"

    xcodebuild archive \
        -scheme MBIssueKit \
        -destination "${destination}" \
        -archivePath "${archive_path}" \
        -derivedDataPath "${derived_data_path}" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        CODE_SIGNING_ALLOWED=NO
}

install_swift_modules() {
    local archive_path="$1"
    local module_path="$2"
    local framework_path="${archive_path}/Products/usr/local/lib/MBIssueKit.framework"

    test -d "${framework_path}"
    test -d "${module_path}"
    mkdir -p "${framework_path}/Modules"
    cp -R "${module_path}" "${framework_path}/Modules/MBIssueKit.swiftmodule"
}

archive "generic/platform=iOS" "${device_archive}" "${device_derived_data}"
install_swift_modules \
    "${device_archive}" \
    "${device_derived_data}/Build/Intermediates.noindex/ArchiveIntermediates/MBIssueKit/BuildProductsPath/Release-iphoneos/MBIssueKit.swiftmodule"

archive "generic/platform=iOS Simulator" "${simulator_archive}" "${simulator_derived_data}"
install_swift_modules \
    "${simulator_archive}" \
    "${simulator_derived_data}/Build/Intermediates.noindex/ArchiveIntermediates/MBIssueKit/BuildProductsPath/Release-iphonesimulator/MBIssueKit.swiftmodule"

xcodebuild -create-xcframework \
    -framework "${device_archive}/Products/usr/local/lib/MBIssueKit.framework" \
    -debug-symbols "${device_archive}/dSYMs/MBIssueKit.framework.dSYM" \
    -framework "${simulator_archive}/Products/usr/local/lib/MBIssueKit.framework" \
    -debug-symbols "${simulator_archive}/dSYMs/MBIssueKit.framework.dSYM" \
    -output "${xcframework_path}"

ditto -c -k --sequesterRsrc --keepParent "${xcframework_path}" "${zip_path}"
swift package compute-checksum "${zip_path}" > "${output_directory}/checksum.txt"

echo "XCFramework: ${xcframework_path}"
echo "Archive: ${zip_path}"
echo "Checksum: $(<"${output_directory}/checksum.txt")"
