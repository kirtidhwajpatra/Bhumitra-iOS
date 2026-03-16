import re

with open('MyBhoomi.xcodeproj/project.pbxproj', 'r') as f:
    text = f.read()

# Add to PBXFrameworksBuildPhase
if '783E1E982F673F5500362470 /* GoogleMobileAds in Frameworks */' not in text:
    text = text.replace(
        '78047C7A2F627C1E00A0CD20 /* MapLibre in Frameworks */,',
        '78047C7A2F627C1E00A0CD20 /* MapLibre in Frameworks */,\n\t\t\t\t783E1E982F673F5500362470 /* GoogleMobileAds in Frameworks */,'
    )

# Add PBXBuildFile
if '783E1E982F673F5500362470 /* GoogleMobileAds in Frameworks */ = {isa = PBXBuildFile' not in text:
    text = text.replace(
        '/* End PBXBuildFile section */',
        '\t\t783E1E982F673F5500362470 /* GoogleMobileAds in Frameworks */ = {isa = PBXBuildFile; productRef = 783E1E982F673F5500362470 /* GoogleMobileAds */; };\n/* End PBXBuildFile section */'
    )

# Add XCRemoteSwiftPackageReference
if '783E1E972F673F5500362470 /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads"' not in text:
    text = text.replace(
        '/* End XCRemoteSwiftPackageReference section */',
        '\t\t783E1E972F673F5500362470 /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = "https://github.com/googleads/swift-package-manager-google-mobile-ads.git";\n\t\t\trequirement = {\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 13.1.0;\n\t\t\t};\n\t\t};\n/* End XCRemoteSwiftPackageReference section */'
    )

if '783E1E9A2F67406C00362470 /* XCRemoteSwiftPackageReference "swift-package-manager-google-user-messaging-platform"' not in text:
    text = text.replace(
        '/* End XCRemoteSwiftPackageReference section */',
        '\t\t783E1E9A2F67406C00362470 /* XCRemoteSwiftPackageReference "swift-package-manager-google-user-messaging-platform" */ = {\n\t\t\tisa = XCRemoteSwiftPackageReference;\n\t\t\trepositoryURL = "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git";\n\t\t\trequirement = {\n\t\t\t\tkind = upToNextMajorVersion;\n\t\t\t\tminimumVersion = 3.1.0;\n\t\t\t};\n\t\t};\n/* End XCRemoteSwiftPackageReference section */'
    )


# Add XCSwiftPackageProductDependency
if '783E1E982F673F5500362470 /* GoogleMobileAds */ = {' not in text:
    text = text.replace(
        '/* End XCSwiftPackageProductDependency section */',
        '\t\t783E1E982F673F5500362470 /* GoogleMobileAds */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = 783E1E972F673F5500362470 /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */;\n\t\t\tproductName = GoogleMobileAds;\n\t\t};\n/* End XCSwiftPackageProductDependency section */'
    )

if '783E1E9B2F67406C00362470 /* GoogleUserMessagingPlatform */ = {' not in text:
    text = text.replace(
        '/* End XCSwiftPackageProductDependency section */',
        '\t\t783E1E9B2F67406C00362470 /* GoogleUserMessagingPlatform */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n\t\t\tpackage = 783E1E9A2F67406C00362470 /* XCRemoteSwiftPackageReference "swift-package-manager-google-user-messaging-platform" */;\n\t\t\tproductName = GoogleUserMessagingPlatform;\n\t\t};\n/* End XCSwiftPackageProductDependency section */'
    )

# Add package references to project root
if '783E1E972F673F5500362470 /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */,' not in text:
    text = text.replace(
        'packageReferences = (',
        'packageReferences = (\n\t\t\t\t783E1E972F673F5500362470 /* XCRemoteSwiftPackageReference "swift-package-manager-google-mobile-ads" */,\n\t\t\t\t783E1E9A2F67406C00362470 /* XCRemoteSwiftPackageReference "swift-package-manager-google-user-messaging-platform" */,'
    )

with open('MyBhoomi.xcodeproj/project.pbxproj', 'w') as f:
    f.write(text)

