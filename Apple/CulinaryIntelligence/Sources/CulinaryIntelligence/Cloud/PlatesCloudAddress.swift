/// The Worker's address. It is empty in the repository, and `ci_scripts/ci_pre_xcodebuild.sh`
/// writes Xcode Cloud's `PLATES_CLOUD_URL` environment variable in here before the build.
nonisolated enum PlatesCloudAddress {
    static let url = ""
}
