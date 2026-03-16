import pbxproj
project = pbxproj.XcodeProject.load('MyBhoomi.xcodeproj/project.pbxproj')

# Add swift package repositories
admob_pkg = project.add_swift_package(repository_url='https://github.com/googleads/swift-package-manager-google-mobile-ads.git', requirement={'kind': 'upToNextMajorVersion', 'minimumVersion': '13.1.0'})
ump_pkg = project.add_swift_package(repository_url='https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git', requirement={'kind': 'upToNextMajorVersion', 'minimumVersion': '3.1.0'})

# Wait, add_swift_package in pbxproj just adds it to project...
# But we need to add the targets to the Frameworks build phase of the MyBhoomi target.
target_name = 'MyBhoomi'
target = project.get_target_by_name(target_name)

# According to pbxproj docs, the easiest way might be doing it manually or via an API point but pbxproj is limited.
# Let's search if python pbxproj supports adding swift package dependencies to targets.
