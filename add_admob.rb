require 'xcodeproj'

project_path = 'MyBhoomi.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'MyBhoomi' }

if target.nil?
  puts "Target 'MyBhoomi' not found."
  exit 1
end

# Check if MapLibre package exists
maplibre_pkg = project.root_object.package_references.find { |pkg| pkg.repositoryURL.include?('maplibre') }

ads_pkg = project.root_object.package_references.find { |pkg| pkg.repositoryURL.include?('swift-package-manager-google-mobile-ads') }
ump_pkg = project.root_object.package_references.find { |pkg| pkg.repositoryURL.include?('swift-package-manager-google-user-messaging-platform') }

if ads_pkg.nil?
  puts "Adding Google Mobile Ads package..."
  ads_pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  ads_pkg.repositoryURL = 'https://github.com/googleads/swift-package-manager-google-mobile-ads.git'
  ads_pkg.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "13.1.0" }
  project.root_object.package_references << ads_pkg
end

if target.package_product_dependencies.find { |dp| dp.product_name == 'GoogleMobileAds' }.nil?
  puts "Adding GoogleMobileAds to target..."
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = ads_pkg
  dep.product_name = 'GoogleMobileAds'
  target.package_product_dependencies << dep
end

if ump_pkg.nil?
  puts "Adding UMP package..."
  ump_pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  ump_pkg.repositoryURL = 'https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git'
  ump_pkg.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "3.1.0" }
  project.root_object.package_references << ump_pkg
end

if target.package_product_dependencies.find { |dp| dp.product_name == 'GoogleUserMessagingPlatform' }.nil?
  puts "Adding GoogleUserMessagingPlatform to target..."
  dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  dep.package = ump_pkg
  dep.product_name = 'GoogleUserMessagingPlatform'
  target.package_product_dependencies << dep
end


# Ensure GoogleMobileAds framework is in "Frameworks" build phase
frameworks_phase = target.frameworks_build_phase
if frameworks_phase
  # For swift packages, usually the framework file isn't added to frameworks_phase directly in xcodeproj
  # Xcode handles it via XCSwiftPackageProductDependency. Let's see if that's enough.
  puts "Done configuring dependencies."
end

project.save
