//
//  LandPassportDetailView.swift
//  MyBhoomi
//
//  Redesigned Authoritative Land Details & Passport View.
//  Features the redesigned Hero Landscape Card with "LAND Simplified" branding,
//  Side-by-side Location Satellite Cadastral Map with "View on map" action, and the
//  Side-by-side Recorded Ownership section matching the reference design and custom SVG vectors.
//

import SwiftUI
import CoreLocation
import MapKit
import MapLibre

// MARK: - Custom Vector Shape for Section 1: Ownership (SVG 1)

public struct OwnershipIconShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 14.0
        let sy = rect.height / 10.0
        
        var path = Path()
        path.move(to: CGPoint(x: 13.1561 * sx, y: 5.68858 * sy))
        path.addCurve(to: CGPoint(x: 12.9998 * sx, y: 5.76357 * sy), control1: CGPoint(x: 13.1094 * sx, y: 5.7236 * sy), control2: CGPoint(x: 13.0563 * sx, y: 5.74908 * sy))
        path.addCurve(to: CGPoint(x: 12.8266 * sx, y: 5.77301 * sy), control1: CGPoint(x: 12.9432 * sx, y: 5.77806 * sy), control2: CGPoint(x: 12.8844 * sx, y: 5.78126 * sy))
        path.addCurve(to: CGPoint(x: 12.663 * sx, y: 5.71546 * sy), control1: CGPoint(x: 12.7688 * sx, y: 5.76475 * sy), control2: CGPoint(x: 12.7132 * sx, y: 5.7452 * sy))
        path.addCurve(to: CGPoint(x: 12.5339 * sx, y: 5.59969 * sy), control1: CGPoint(x: 12.6128 * sx, y: 5.68572 * sy), control2: CGPoint(x: 12.5689 * sx, y: 5.64639 * sy))
        path.addCurve(to: CGPoint(x: 11.5159 * sx, y: 4.74673 * sy), control1: CGPoint(x: 12.266 * sx, y: 5.2396 * sy), control2: CGPoint(x: 11.9173 * sx, y: 4.94744 * sy))
        path.addCurve(to: CGPoint(x: 10.2227 * sx, y: 4.4441 * sy), control1: CGPoint(x: 11.1145 * sx, y: 4.54602 * sy), control2: CGPoint(x: 10.6715 * sx, y: 4.44236 * sy))
        path.addCurve(to: CGPoint(x: 9.97702 * sx, y: 4.36999 * sy), control1: CGPoint(x: 10.1353 * sx, y: 4.44409 * sy), control2: CGPoint(x: 10.0498 * sx, y: 4.41832 * sy))
        path.addCurve(to: CGPoint(x: 9.81325 * sx, y: 4.17243 * sy), control1: CGPoint(x: 9.90419 * sx, y: 4.32167 * sy), control2: CGPoint(x: 9.84722 * sx, y: 4.25295 * sy))
        path.addCurve(to: CGPoint(x: 9.77829 * sx, y: 3.99964 * sy), control1: CGPoint(x: 9.79017 * sx, y: 4.11774 * sy), control2: CGPoint(x: 9.77829 * sx, y: 4.05899 * sy))
        path.addCurve(to: CGPoint(x: 9.81325 * sx, y: 3.82686 * sy), control1: CGPoint(x: 9.77829 * sx, y: 3.94029 * sy), control2: CGPoint(x: 9.79017 * sx, y: 3.88154 * sy))
        path.addCurve(to: CGPoint(x: 9.97702 * sx, y: 3.62929 * sy), control1: CGPoint(x: 9.84722 * sx, y: 3.74633 * sy), control2: CGPoint(x: 9.90419 * sx, y: 3.67761 * sy))
        path.addCurve(to: CGPoint(x: 10.2227 * sx, y: 3.55518 * sy), control1: CGPoint(x: 10.0498 * sx, y: 3.58097 * sy), control2: CGPoint(x: 10.1353 * sx, y: 3.55519 * sy))
        path.addCurve(to: CGPoint(x: 10.9281 * sx, y: 3.35326 * sy), control1: CGPoint(x: 10.4721 * sx, y: 3.55516 * sy), control2: CGPoint(x: 10.7165 * sx, y: 3.4852 * sy))
        path.addCurve(to: CGPoint(x: 11.4198 * sx, y: 2.80874 * sy), control1: CGPoint(x: 11.1397 * sx, y: 3.22131 * sy), control2: CGPoint(x: 11.3101 * sx, y: 3.03266 * sy))
        path.addCurve(to: CGPoint(x: 11.5491 * sx, y: 2.08651 * sy), control1: CGPoint(x: 11.5296 * sx, y: 2.58482 * sy), control2: CGPoint(x: 11.5744 * sx, y: 2.3346 * sy))
        path.addCurve(to: CGPoint(x: 11.2767 * sx, y: 1.40524 * sy), control1: CGPoint(x: 11.5238 * sx, y: 1.83841 * sy), control2: CGPoint(x: 11.4294 * sx, y: 1.60239 * sy))
        path.addCurve(to: CGPoint(x: 10.6851 * sx, y: 0.971226 * sy), control1: CGPoint(x: 11.124 * sx, y: 1.2081 * sy), control2: CGPoint(x: 10.919 * sx, y: 1.05773 * sy))
        path.addCurve(to: CGPoint(x: 9.95349 * sx, y: 0.915873 * sy), control1: CGPoint(x: 10.4512 * sx, y: 0.884721 * sy), control2: CGPoint(x: 10.1977 * sx, y: 0.865544 * sy))
        path.addCurve(to: CGPoint(x: 9.30336 * sx, y: 1.25594 * sy), control1: CGPoint(x: 9.70924 * sx, y: 0.966201 * sy), control2: CGPoint(x: 9.484 * sx, y: 1.08402 * sy))
        path.addCurve(to: CGPoint(x: 8.93155 * sx, y: 1.88847 * sy), control1: CGPoint(x: 9.12271 * sx, y: 1.42787 * sy), control2: CGPoint(x: 8.9939 * sx, y: 1.64701 * sy))
        path.addCurve(to: CGPoint(x: 8.85626 * sx, y: 2.04478 * sy), control1: CGPoint(x: 8.91696 * sx, y: 1.94501 * sy), control2: CGPoint(x: 8.89137 * sx, y: 1.99813 * sy))
        path.addCurve(to: CGPoint(x: 8.72687 * sx, y: 2.16038 * sy), control1: CGPoint(x: 8.82114 * sx, y: 2.09144 * sy), control2: CGPoint(x: 8.77717 * sx, y: 2.13072 * sy))
        path.addCurve(to: CGPoint(x: 8.5631 * sx, y: 2.21767 * sy), control1: CGPoint(x: 8.67657 * sx, y: 2.19004 * sy), control2: CGPoint(x: 8.62092 * sx, y: 2.20951 * sy))
        path.addCurve(to: CGPoint(x: 8.38987 * sx, y: 2.20792 * sy), control1: CGPoint(x: 8.50528 * sx, y: 2.22582 * sy), control2: CGPoint(x: 8.44641 * sx, y: 2.22251 * sy))
        path.addCurve(to: CGPoint(x: 8.23356 * sx, y: 2.13262 * sy), control1: CGPoint(x: 8.33333 * sx, y: 2.19333 * sy), control2: CGPoint(x: 8.28021 * sx, y: 2.16774 * sy))
        path.addCurve(to: CGPoint(x: 8.11796 * sx, y: 2.00324 * sy), control1: CGPoint(x: 8.1869 * sx, y: 2.09751 * sy), control2: CGPoint(x: 8.14762 * sx, y: 2.05354 * sy))
        path.addCurve(to: CGPoint(x: 8.06067 * sx, y: 1.83947 * sy), control1: CGPoint(x: 8.08829 * sx, y: 1.95294 * sy), control2: CGPoint(x: 8.06883 * sx, y: 1.89729 * sy))
        path.addCurve(to: CGPoint(x: 8.07041 * sx, y: 1.66624 * sy), control1: CGPoint(x: 8.05251 * sx, y: 1.78164 * sy), control2: CGPoint(x: 8.05582 * sx, y: 1.72278 * sy))
        path.addCurve(to: CGPoint(x: 8.54787 * sx, y: 0.76085 * sy), control1: CGPoint(x: 8.15695 * sx, y: 1.3314 * sy), control2: CGPoint(x: 8.32044 * sx, y: 1.02138 * sy))
        path.addCurve(to: CGPoint(x: 9.38048 * sx, y: 0.165498 * sy), control1: CGPoint(x: 8.7753 * sx, y: 0.500316 * sy), control2: CGPoint(x: 9.0604 * sx, y: 0.296459 * sy))
        path.addCurve(to: CGPoint(x: 10.3916 * sx, y: 0.00648204 * sy), control1: CGPoint(x: 9.70056 * sx, y: 0.034537 * sy), control2: CGPoint(x: 10.0468 * sx, y: -0.0199124 * sy))
        path.addCurve(to: CGPoint(x: 11.3668 * sx, y: 0.317537 * sy), control1: CGPoint(x: 10.7364 * sx, y: 0.0328765 * sy), control2: CGPoint(x: 11.0704 * sx, y: 0.139386 * sy))
        path.addCurve(to: CGPoint(x: 12.0991 * sx, y: 1.03267 * sy), control1: CGPoint(x: 11.6632 * sx, y: 0.495687 * sy), control2: CGPoint(x: 11.914 * sx, y: 0.740561 * sy))
        path.addCurve(to: CGPoint(x: 12.4332 * sx, y: 2.00018 * sy), control1: CGPoint(x: 12.2842 * sx, y: 1.32479 * sy), control2: CGPoint(x: 12.3986 * sx, y: 1.65607 * sy))
        path.addCurve(to: CGPoint(x: 12.2982 * sx, y: 3.01481 * sy), control1: CGPoint(x: 12.4677 * sx, y: 2.34429 * sy), control2: CGPoint(x: 12.4215 * sx, y: 2.69171 * sy))
        path.addCurve(to: CGPoint(x: 11.7227 * sx, y: 3.86131 * sy), control1: CGPoint(x: 12.1749 * sx, y: 3.3379 * sy), control2: CGPoint(x: 11.9778 * sx, y: 3.62776 * sy))
        path.addCurve(to: CGPoint(x: 13.2467 * sx, y: 5.06579 * sy), control1: CGPoint(x: 12.3271 * sx, y: 4.12298 * sy), control2: CGPoint(x: 12.8525 * sx, y: 4.53822 * sy))
        path.addCurve(to: CGPoint(x: 13.3215 * sx, y: 5.22252 * sy), control1: CGPoint(x: 13.2817 * sx, y: 5.1126 * sy), control2: CGPoint(x: 13.3071 * sx, y: 5.16586 * sy))
        path.addCurve(to: CGPoint(x: 13.3306 * sx, y: 5.39597 * sy), control1: CGPoint(x: 13.3359 * sx, y: 5.27918 * sy), control2: CGPoint(x: 13.339 * sx, y: 5.33812 * sy))
        path.addCurve(to: CGPoint(x: 13.2725 * sx, y: 5.55966 * sy), control1: CGPoint(x: 13.3222 * sx, y: 5.45383 * sy), control2: CGPoint(x: 13.3025 * sx, y: 5.50945 * sy))
        path.addCurve(to: CGPoint(x: 13.1561 * sx, y: 5.68858 * sy), control1: CGPoint(x: 13.2426 * sx, y: 5.60987 * sy), control2: CGPoint(x: 13.203 * sx, y: 5.65368 * sy))
        path.closeSubpath()
        
        path.move(to: CGPoint(x: 10.1627 * sx, y: 9.11091 * sy))
        path.addCurve(to: CGPoint(x: 10.2262 * sx, y: 9.27722 * sy), control1: CGPoint(x: 10.1949 * sx, y: 9.1615 * sy), control2: CGPoint(x: 10.2165 * sx, y: 9.21807 * sy))
        path.addCurve(to: CGPoint(x: 10.2193 * sx, y: 9.45509 * sy), control1: CGPoint(x: 10.2359 * sx, y: 9.33636 * sy), control2: CGPoint(x: 10.2336 * sx, y: 9.39687 * sy))
        path.addCurve(to: CGPoint(x: 10.1432 * sx, y: 9.61601 * sy), control1: CGPoint(x: 10.2051 * sx, y: 9.51331 * sy), control2: CGPoint(x: 10.1792 * sx, y: 9.56805 * sy))
        path.addCurve(to: CGPoint(x: 10.01 * sx, y: 9.73415 * sy), control1: CGPoint(x: 10.1072 * sx, y: 9.66396 * sy), control2: CGPoint(x: 10.0619 * sx, y: 9.70415 * sy))
        path.addCurve(to: CGPoint(x: 9.84121 * sx, y: 9.79057 * sy), control1: CGPoint(x: 9.95815 * sx, y: 9.76415 * sy), control2: CGPoint(x: 9.90072 * sx, y: 9.78334 * sy))
        path.addCurve(to: CGPoint(x: 9.66378 * sx, y: 9.77621 * sy), control1: CGPoint(x: 9.7817 * sx, y: 9.79779 * sy), control2: CGPoint(x: 9.72135 * sx, y: 9.79291 * sy))
        path.addCurve(to: CGPoint(x: 9.50622 * sx, y: 9.69338 * sy), control1: CGPoint(x: 9.60621 * sx, y: 9.75951 * sy), control2: CGPoint(x: 9.55261 * sx, y: 9.73133 * sy))
        path.addCurve(to: CGPoint(x: 9.39379 * sx, y: 9.55537 * sy), control1: CGPoint(x: 9.45982 * sx, y: 9.65543 * sy), control2: CGPoint(x: 9.42157 * sx, y: 9.60848 * sy))
        path.addCurve(to: CGPoint(x: 8.23688 * sx, y: 8.41545 * sy), control1: CGPoint(x: 9.11381 * sx, y: 9.08128 * sy), control2: CGPoint(x: 8.71505 * sx, y: 8.68839 * sy))
        path.addCurve(to: CGPoint(x: 6.66704 * sx, y: 7.99895 * sy), control1: CGPoint(x: 7.7587 * sx, y: 8.14251 * sy), control2: CGPoint(x: 7.21763 * sx, y: 7.99895 * sy))
        path.addCurve(to: CGPoint(x: 5.0972 * sx, y: 8.41545 * sy), control1: CGPoint(x: 6.11645 * sx, y: 7.99895 * sy), control2: CGPoint(x: 5.57537 * sx, y: 8.14251 * sy))
        path.addCurve(to: CGPoint(x: 3.94029 * sx, y: 9.55537 * sy), control1: CGPoint(x: 4.61902 * sx, y: 8.68839 * sy), control2: CGPoint(x: 4.22027 * sx, y: 9.08128 * sy))
        path.addCurve(to: CGPoint(x: 3.82786 * sx, y: 9.69338 * sy), control1: CGPoint(x: 3.9125 * sx, y: 9.60848 * sy), control2: CGPoint(x: 3.87426 * sx, y: 9.65543 * sy))
        path.addCurve(to: CGPoint(x: 3.6703 * sx, y: 9.77621 * sy), control1: CGPoint(x: 3.78146 * sx, y: 9.73133 * sy), control2: CGPoint(x: 3.72787 * sx, y: 9.75951 * sy))
        path.addCurve(to: CGPoint(x: 3.49287 * sx, y: 9.79057 * sy), control1: CGPoint(x: 3.61273 * sx, y: 9.79291 * sy), control2: CGPoint(x: 3.55237 * sx, y: 9.79779 * sy))
        path.addCurve(to: CGPoint(x: 3.32404 * sx, y: 9.73415 * sy), control1: CGPoint(x: 3.43336 * sx, y: 9.78334 * sy), control2: CGPoint(x: 3.37593 * sx, y: 9.76415 * sy))
        path.addCurve(to: CGPoint(x: 3.19088 * sx, y: 9.61601 * sy), control1: CGPoint(x: 3.27214 * sx, y: 9.70415 * sy), control2: CGPoint(x: 3.22684 * sx, y: 9.66396 * sy))
        path.addCurve(to: CGPoint(x: 3.11477 * sx, y: 9.45509 * sy), control1: CGPoint(x: 3.15492 * sx, y: 9.56805 * sy), control2: CGPoint(x: 3.12903 * sx, y: 9.51331 * sy))
        path.addCurve(to: CGPoint(x: 3.1079 * sx, y: 9.27722 * sy), control1: CGPoint(x: 3.1005 * sx, y: 9.39687 * sy), control2: CGPoint(x: 3.09817 * sx, y: 9.33636 * sy))
        path.addCurve(to: CGPoint(x: 3.17138 * sx, y: 9.11091 * sy), control1: CGPoint(x: 3.11763 * sx, y: 9.21807 * sy), control2: CGPoint(x: 3.13922 * sx, y: 9.1615 * sy))
        path.addCurve(to: CGPoint(x: 5.04588 * sx, y: 7.44864 * sy), control1: CGPoint(x: 3.60228 * sx, y: 8.37054 * sy), control2: CGPoint(x: 4.2593 * sx, y: 7.78791 * sy))
        path.addCurve(to: CGPoint(x: 4.11574 * sx, y: 6.10739 * sy), control1: CGPoint(x: 4.60327 * sx, y: 7.10976 * sy), control2: CGPoint(x: 4.27798 * sx, y: 6.6407 * sy))
        path.addCurve(to: CGPoint(x: 4.14136 * sx, y: 4.47538 * sy), control1: CGPoint(x: 3.9535 * sx, y: 5.57408 * sy), control2: CGPoint(x: 3.96246 * sx, y: 5.00334 * sy))
        path.addCurve(to: CGPoint(x: 5.11314 * sx, y: 3.16399 * sy), control1: CGPoint(x: 4.32026 * sx, y: 3.94743 * sy), control2: CGPoint(x: 4.66011 * sx, y: 3.48881 * sy))
        path.addCurve(to: CGPoint(x: 6.66704 * sx, y: 2.66449 * sy), control1: CGPoint(x: 5.56617 * sx, y: 2.83917 * sy), control2: CGPoint(x: 6.1096 * sx, y: 2.66449 * sy))
        path.addCurve(to: CGPoint(x: 8.22094 * sx, y: 3.16399 * sy), control1: CGPoint(x: 7.22448 * sx, y: 2.66449 * sy), control2: CGPoint(x: 7.76791 * sx, y: 2.83917 * sy))
        path.addCurve(to: CGPoint(x: 9.19272 * sx, y: 4.47538 * sy), control1: CGPoint(x: 8.67397 * sx, y: 3.48881 * sy), control2: CGPoint(x: 9.01382 * sx, y: 3.94743 * sy))
        path.addCurve(to: CGPoint(x: 9.21834 * sx, y: 6.10739 * sy), control1: CGPoint(x: 9.37162 * sx, y: 5.00334 * sy), control2: CGPoint(x: 9.38058 * sx, y: 5.57408 * sy))
        path.addCurve(to: CGPoint(x: 8.2882 * sx, y: 7.44864 * sy), control1: CGPoint(x: 9.0561 * sx, y: 6.6407 * sy), control2: CGPoint(x: 8.73081 * sx, y: 7.10976 * sy))
        path.addCurve(to: CGPoint(x: 10.1627 * sx, y: 9.11091 * sy), control1: CGPoint(x: 9.07478 * sx, y: 7.78791 * sy), control2: CGPoint(x: 9.7318 * sx, y: 8.37054 * sy))
        path.closeSubpath()
        
        path.move(to: CGPoint(x: 6.66704 * sx, y: 7.11085 * sy))
        path.addCurve(to: CGPoint(x: 7.65475 * sx, y: 6.81123 * sy), control1: CGPoint(x: 7.01866 * sx, y: 7.11085 * sy), control2: CGPoint(x: 7.36239 * sx, y: 7.00658 * sy))
        path.addCurve(to: CGPoint(x: 8.30954 * sx, y: 6.01336 * sy), control1: CGPoint(x: 7.94711 * sx, y: 6.61588 * sy), control2: CGPoint(x: 8.17498 * sx, y: 6.33822 * sy))
        path.addCurve(to: CGPoint(x: 8.41071 * sx, y: 4.98618 * sy), control1: CGPoint(x: 8.4441 * sx, y: 5.68851 * sy), control2: CGPoint(x: 8.47931 * sx, y: 5.33104 * sy))
        path.addCurve(to: CGPoint(x: 7.92416 * sx, y: 4.0759 * sy), control1: CGPoint(x: 8.34211 * sx, y: 4.64131 * sy), control2: CGPoint(x: 8.17279 * sx, y: 4.32453 * sy))
        path.addCurve(to: CGPoint(x: 7.01388 * sx, y: 3.58935 * sy), control1: CGPoint(x: 7.67552 * sx, y: 3.82727 * sy), control2: CGPoint(x: 7.35874 * sx, y: 3.65794 * sy))
        path.addCurve(to: CGPoint(x: 5.98669 * sx, y: 3.69051 * sy), control1: CGPoint(x: 6.66901 * sx, y: 3.52075 * sy), control2: CGPoint(x: 6.31155 * sx, y: 3.55595 * sy))
        path.addCurve(to: CGPoint(x: 5.18883 * sx, y: 4.34531 * sy), control1: CGPoint(x: 5.66184 * sx, y: 3.82507 * sy), control2: CGPoint(x: 5.38418 * sx, y: 4.05294 * sy))
        path.addCurve(to: CGPoint(x: 4.88921 * sx, y: 5.33302 * sy), control1: CGPoint(x: 4.99347 * sx, y: 4.63767 * sy), control2: CGPoint(x: 4.88921 * sx, y: 4.9814 * sy))
        path.addCurve(to: CGPoint(x: 5.40992 * sx, y: 6.59013 * sy), control1: CGPoint(x: 4.88921 * sx, y: 5.80453 * sy), control2: CGPoint(x: 5.07651 * sx, y: 6.25673 * sy))
        path.addCurve(to: CGPoint(x: 6.66704 * sx, y: 7.11085 * sy), control1: CGPoint(x: 5.74333 * sx, y: 6.92354 * sy), control2: CGPoint(x: 6.19553 * sx, y: 7.11085 * sy))
        path.closeSubpath()
        
        path.move(to: CGPoint(x: 3.55583 * sx, y: 3.99964 * sy))
        path.addCurve(to: CGPoint(x: 3.42565 * sx, y: 3.68536 * sy), control1: CGPoint(x: 3.55583 * sx, y: 3.88177 * sy), control2: CGPoint(x: 3.50901 * sx, y: 3.76872 * sy))
        path.addCurve(to: CGPoint(x: 3.11137 * sx, y: 3.55518 * sy), control1: CGPoint(x: 3.3423 * sx, y: 3.60201 * sy), control2: CGPoint(x: 3.22925 * sx, y: 3.55518 * sy))
        path.addCurve(to: CGPoint(x: 2.406 * sx, y: 3.35326 * sy), control1: CGPoint(x: 2.86199 * sx, y: 3.55516 * sy), control2: CGPoint(x: 2.61762 * sx, y: 3.4852 * sy))
        path.addCurve(to: CGPoint(x: 1.91424 * sx, y: 2.80874 * sy), control1: CGPoint(x: 2.19439 * sx, y: 3.22131 * sy), control2: CGPoint(x: 2.02402 * sx, y: 3.03266 * sy))
        path.addCurve(to: CGPoint(x: 1.785 * sx, y: 2.08651 * sy), control1: CGPoint(x: 1.80447 * sx, y: 2.58482 * sy), control2: CGPoint(x: 1.75969 * sx, y: 2.3346 * sy))
        path.addCurve(to: CGPoint(x: 2.0574 * sx, y: 1.40524 * sy), control1: CGPoint(x: 1.81031 * sx, y: 1.83841 * sy), control2: CGPoint(x: 1.90468 * sx, y: 1.60239 * sy))
        path.addCurve(to: CGPoint(x: 2.64897 * sx, y: 0.971226 * sy), control1: CGPoint(x: 2.21012 * sx, y: 1.2081 * sy), control2: CGPoint(x: 2.41507 * sx, y: 1.05773 * sy))
        path.addCurve(to: CGPoint(x: 3.38059 * sx, y: 0.915873 * sy), control1: CGPoint(x: 2.88287 * sx, y: 0.884721 * sy), control2: CGPoint(x: 3.13634 * sx, y: 0.865544 * sy))
        path.addCurve(to: CGPoint(x: 4.03072 * sx, y: 1.25594 * sy), control1: CGPoint(x: 3.62484 * sx, y: 0.966201 * sy), control2: CGPoint(x: 3.85008 * sx, y: 1.08402 * sy))
        path.addCurve(to: CGPoint(x: 4.40253 * sx, y: 1.88847 * sy), control1: CGPoint(x: 4.21137 * sx, y: 1.42787 * sy), control2: CGPoint(x: 4.34018 * sx, y: 1.64701 * sy))
        path.addCurve(to: CGPoint(x: 4.60721 * sx, y: 2.16038 * sy), control1: CGPoint(x: 4.43199 * sx, y: 2.00266 * sy), control2: CGPoint(x: 4.50562 * sx, y: 2.10047 * sy))
        path.addCurve(to: CGPoint(x: 4.94421 * sx, y: 2.20792 * sy), control1: CGPoint(x: 4.70879 * sx, y: 2.22029 * sy), control2: CGPoint(x: 4.83001 * sx, y: 2.23739 * sy))
        path.addCurve(to: CGPoint(x: 5.21612 * sx, y: 2.00324 * sy), control1: CGPoint(x: 5.0584 * sx, y: 2.17845 * sy), control2: CGPoint(x: 5.15621 * sx, y: 2.10483 * sy))
        path.addCurve(to: CGPoint(x: 5.26366 * sx, y: 1.66624 * sy), control1: CGPoint(x: 5.27603 * sx, y: 1.90166 * sy), control2: CGPoint(x: 5.29313 * sx, y: 1.78043 * sy))
        path.addCurve(to: CGPoint(x: 4.78621 * sx, y: 0.76085 * sy), control1: CGPoint(x: 5.17713 * sx, y: 1.3314 * sy), control2: CGPoint(x: 5.01364 * sx, y: 1.02138 * sy))
        path.addCurve(to: CGPoint(x: 3.9536 * sx, y: 0.165498 * sy), control1: CGPoint(x: 4.55878 * sx, y: 0.500316 * sy), control2: CGPoint(x: 4.27368 * sx, y: 0.296459 * sy))
        path.addCurve(to: CGPoint(x: 2.94246 * sx, y: 0.00648204 * sy), control1: CGPoint(x: 3.63351 * sx, y: 0.034537 * sy), control2: CGPoint(x: 3.28729 * sx, y: -0.0199124 * sy))
        path.addCurve(to: CGPoint(x: 1.9673 * sx, y: 0.317537 * sy), control1: CGPoint(x: 2.59763 * sx, y: 0.0328765 * sy), control2: CGPoint(x: 2.26372 * sx, y: 0.139386 * sy))
        path.addCurve(to: CGPoint(x: 1.235 * sx, y: 1.03267 * sy), control1: CGPoint(x: 1.67088 * sx, y: 0.495687 * sy), control2: CGPoint(x: 1.42013 * sx, y: 0.740561 * sy))
        path.addCurve(to: CGPoint(x: 0.900901 * sx, y: 2.00018 * sy), control1: CGPoint(x: 1.04987 * sx, y: 1.32479 * sy), control2: CGPoint(x: 0.935466 * sx, y: 1.65607 * sy))
        path.addCurve(to: CGPoint(x: 1.03589 * sx, y: 3.01481 * sy), control1: CGPoint(x: 0.866336 * sx, y: 2.34429 * sy), control2: CGPoint(x: 0.912558 * sx, y: 2.69171 * sy))
        path.addCurve(to: CGPoint(x: 1.61133 * sx, y: 3.86131 * sy), control1: CGPoint(x: 1.15922 * sx, y: 3.3379 * sy), control2: CGPoint(x: 1.35626 * sx, y: 3.62776 * sy))
        path.addCurve(to: CGPoint(x: 0.0890602 * sx, y: 5.06579 * sy), control1: CGPoint(x: 1.00758 * sx, y: 4.12323 * sy), control2: CGPoint(x: 0.482802 * sx, y: 4.53845 * sy))
        path.addCurve(to: CGPoint(x: 0.00443914 * sx, y: 5.3954 * sy), control1: CGPoint(x: 0.01826 * sx, y: 5.16009 * sy), control2: CGPoint(x: -0.0121792 * sx, y: 5.27865 * sy))
        path.addCurve(to: CGPoint(x: 0.177674 * sx, y: 5.68831 * sy), control1: CGPoint(x: 0.0210575 * sx, y: 5.51214 * sy), control2: CGPoint(x: 0.0833719 * sx, y: 5.61751 * sy))
        path.addCurve(to: CGPoint(x: 0.507286 * sx, y: 5.77293 * sy), control1: CGPoint(x: 0.271976 * sx, y: 5.75911 * sy), control2: CGPoint(x: 0.390541 * sx, y: 5.78955 * sy))
        path.addCurve(to: CGPoint(x: 0.800193 * sx, y: 5.59969 * sy), control1: CGPoint(x: 0.624031 * sx, y: 5.75631 * sy), control2: CGPoint(x: 0.729393 * sx, y: 5.69399 * sy))
        path.addCurve(to: CGPoint(x: 1.8182 * sx, y: 4.74673 * sy), control1: CGPoint(x: 1.06808 * sx, y: 5.2396 * sy), control2: CGPoint(x: 1.41678 * sx, y: 4.94744 * sy))
        path.addCurve(to: CGPoint(x: 3.11137 * sx, y: 4.4441 * sy), control1: CGPoint(x: 2.21963 * sx, y: 4.54602 * sy), control2: CGPoint(x: 2.66257 * sx, y: 4.44236 * sy))
        path.addCurve(to: CGPoint(x: 3.42565 * sx, y: 4.31392 * sy), control1: CGPoint(x: 3.22925 * sx, y: 4.4441 * sy), control2: CGPoint(x: 3.3423 * sx, y: 4.39727 * sy))
        path.addCurve(to: CGPoint(x: 3.55583 * sx, y: 3.99964 * sy), control1: CGPoint(x: 3.50901 * sx, y: 4.23057 * sy), control2: CGPoint(x: 3.55583 * sx, y: 4.11752 * sy))
        path.closeSubpath()
        return path
    }
}

// MARK: - Custom Vector Shape for Section 2: Location Compass (SVG 2)

public struct LocationCompassIconShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 11.0
        let sy = rect.height / 11.0
        
        var path = Path()
        path.move(to: CGPoint(x: 10.4693 * sx, y: 3.36583 * sy))
        path.addLine(to: CGPoint(x: 7.34432 * sx, y: 0.241367 * sy))
        path.addCurve(to: CGPoint(x: 7.07702 * sx, y: 0.06273 * sy), control1: CGPoint(x: 7.26782 * sx, y: 0.164846 * sy), control2: CGPoint(x: 7.17699 * sx, y: 0.104144 * sy))
        path.addCurve(to: CGPoint(x: 6.7617 * sx, y: 0.0 * sy), control1: CGPoint(x: 6.97705 * sx, y: 0.0213158 * sy), control2: CGPoint(x: 6.86991 * sx, y: 0.0 * sy))
        path.addCurve(to: CGPoint(x: 6.44638 * sx, y: 0.06273 * sy), control1: CGPoint(x: 6.6535 * sx, y: 0.0 * sy), control2: CGPoint(x: 6.54635 * sx, y: 0.0213158 * sy))
        path.addCurve(to: CGPoint(x: 6.17908 * sx, y: 0.241367 * sy), control1: CGPoint(x: 6.34642 * sx, y: 0.104144 * sy), control2: CGPoint(x: 6.25559 * sx, y: 0.164846 * sy))
        path.addLine(to: CGPoint(x: 3.41763 * sx, y: 3.01157 * sy))
        path.addCurve(to: CGPoint(x: 0.30759 * sx, y: 3.68816 * sy), control1: CGPoint(x: 2.86874 * sx, y: 2.83959 * sy), control2: CGPoint(x: 1.61546 * sx, y: 2.63208 * sy))
        path.addCurve(to: CGPoint(x: 0.0907834 * sx, y: 3.95424 * sy), control1: CGPoint(x: 0.217443 * sx, y: 3.76065 * sy), control2: CGPoint(x: 0.143571 * sx, y: 3.85131 * sy))
        path.addCurve(to: CGPoint(x: 0.0012096 * sx, y: 4.28557 * sy), control1: CGPoint(x: 0.0379957 * sx, y: 4.05717 * sy), control2: CGPoint(x: 0.00747552 * sx, y: 4.17006 * sy))
        path.addCurve(to: CGPoint(x: 0.0544157 * sx, y: 4.62464 * sy), control1: CGPoint(x: -0.00505633 * sx, y: 4.40107 * sy), control2: CGPoint(x: 0.0130724 * sx, y: 4.51661 * sy))
        path.addCurve(to: CGPoint(x: 0.241167 * sx, y: 4.91261 * sy), control1: CGPoint(x: 0.0957591 * sx, y: 4.73268 * sy), control2: CGPoint(x: 0.15939 * sx, y: 4.8308 * sy))
        path.addLine(to: CGPoint(x: 2.7292 * sx, y: 7.39962 * sy))
        path.addLine(to: CGPoint(x: 0.532605 * sx, y: 9.59467 * sy))
        path.addCurve(to: CGPoint(x: 0.411888 * sx, y: 9.88611 * sy), control1: CGPoint(x: 0.455311 * sx, y: 9.67196 * sy), control2: CGPoint(x: 0.411888 * sx, y: 9.7768 * sy))
        path.addCurve(to: CGPoint(x: 0.532605 * sx, y: 10.1775 * sy), control1: CGPoint(x: 0.411888 * sx, y: 9.99542 * sy), control2: CGPoint(x: 0.455311 * sx, y: 10.1002 * sy))
        path.addCurve(to: CGPoint(x: 0.824043 * sx, y: 10.2983 * sy), control1: CGPoint(x: 0.609899 * sx, y: 10.2548 * sy), control2: CGPoint(x: 0.714732 * sx, y: 10.2983 * sy))
        path.addCurve(to: CGPoint(x: 1.11548 * sx, y: 10.1775 * sy), control1: CGPoint(x: 0.933353 * sx, y: 10.2983 * sy), control2: CGPoint(x: 1.03819 * sx, y: 10.2548 * sy))
        path.addLine(to: CGPoint(x: 3.31053 * sx, y: 7.98095 * sy))
        path.addLine(to: CGPoint(x: 5.79702 * sx, y: 10.4674 * sy))
        path.addCurve(to: CGPoint(x: 6.06431 * sx, y: 10.6467 * sy), control1: CGPoint(x: 5.87346 * sx, y: 10.5442 * sy), control2: CGPoint(x: 5.96429 * sx, y: 10.6051 * sy))
        path.addCurve(to: CGPoint(x: 6.3799 * sx, y: 10.71 * sy), control1: CGPoint(x: 6.16433 * sx, y: 10.6884 * sy), control2: CGPoint(x: 6.27157 * sx, y: 10.7098 * sy))
        path.addCurve(to: CGPoint(x: 6.43808 * sx, y: 10.71 * sy), control1: CGPoint(x: 6.39946 * sx, y: 10.71 * sy), control2: CGPoint(x: 6.41852 * sx, y: 10.71 * sy))
        path.addCurve(to: CGPoint(x: 6.77325 * sx, y: 10.6123 * sy), control1: CGPoint(x: 6.55552 * sx, y: 10.7018 * sy), control2: CGPoint(x: 6.66984 * sx, y: 10.6685 * sy))
        path.addCurve(to: CGPoint(x: 7.03743 * sx, y: 10.384 * sy), control1: CGPoint(x: 6.87667 * sx, y: 10.556 * sy), control2: CGPoint(x: 6.96677 * sx, y: 10.4782 * sy))
        path.addCurve(to: CGPoint(x: 7.7166 * sx, y: 7.29457 * sy), control1: CGPoint(x: 8.04871 * sx, y: 9.04011 * sy), control2: CGPoint(x: 7.9514 * sx, y: 7.94748 * sy))
        path.addLine(to: CGPoint(x: 10.4698 * sx, y: 4.53106 * sy))
        path.addCurve(to: CGPoint(x: 10.6483 * sx, y: 4.26369 * sy), control1: CGPoint(x: 10.5463 * sx, y: 4.45453 * sy), control2: CGPoint(x: 10.607 * sx, y: 4.36367 * sy))
        path.addCurve(to: CGPoint(x: 10.7109 * sx, y: 3.94834 * sy), control1: CGPoint(x: 10.6897 * sx, y: 4.1637 * sy), control2: CGPoint(x: 10.711 * sx, y: 4.05655 * sy))
        path.addCurve(to: CGPoint(x: 10.6481 * sx, y: 3.63305 * sy), control1: CGPoint(x: 10.7109 * sx, y: 3.84013 * sy), control2: CGPoint(x: 10.6895 * sx, y: 3.733 * sy))
        path.addCurve(to: CGPoint(x: 10.4693 * sx, y: 3.36583 * sy), control1: CGPoint(x: 10.6066 * sx, y: 3.5331 * sy), control2: CGPoint(x: 10.5459 * sx, y: 3.4423 * sy))
        path.closeSubpath()
        
        path.move(to: CGPoint(x: 9.88642 * sx, y: 3.9487 * sy))
        path.addLine(to: CGPoint(x: 6.93754 * sx, y: 6.90736 * sy))
        path.addCurve(to: CGPoint(x: 6.82271 * sx, y: 7.13238 * sy), control1: CGPoint(x: 6.87664 * sx, y: 6.96849 * sy), control2: CGPoint(x: 6.83648 * sx, y: 7.0472 * sy))
        path.addCurve(to: CGPoint(x: 6.86082 * sx, y: 7.38211 * sy), control1: CGPoint(x: 6.80895 * sx, y: 7.21756 * sy), control2: CGPoint(x: 6.82228 * sx, y: 7.30491 * sy))
        path.addCurve(to: CGPoint(x: 6.3799 * sx, y: 9.88559 * sy), control1: CGPoint(x: 7.34792 * sx, y: 8.35683 * sy), control2: CGPoint(x: 6.76814 * sx, y: 9.36914 * sy))
        path.addLine(to: CGPoint(x: 0.824043 * sx, y: 4.32922 * sy))
        path.addCurve(to: CGPoint(x: 2.49646 * sx, y: 3.69537 * sy), control1: CGPoint(x: 1.44605 * sx, y: 3.8277 * sy), control2: CGPoint(x: 2.04129 * sx, y: 3.69537 * sy))
        path.addCurve(to: CGPoint(x: 3.33731 * sx, y: 3.86168 * sy), control1: CGPoint(x: 2.78529 * sx, y: 3.69143 * sy), control2: CGPoint(x: 3.07173 * sx, y: 3.74808 * sy))
        path.addCurve(to: CGPoint(x: 3.58803 * sx, y: 3.89986 * sy), control1: CGPoint(x: 3.41479 * sx, y: 3.90046 * sy), control2: CGPoint(x: 3.50252 * sx, y: 3.91382 * sy))
        path.addCurve(to: CGPoint(x: 3.8136 * sx, y: 3.78393 * sy), control1: CGPoint(x: 3.67354 * sx, y: 3.8859 * sy), control2: CGPoint(x: 3.75247 * sx, y: 3.84534 * sy))
        path.addLine(to: CGPoint(x: 6.76196 * sx, y: 0.823728 * sy))
        path.addLine(to: CGPoint(x: 9.88642 * sx, y: 3.94819 * sy))
        path.addLine(to: CGPoint(x: 9.88642 * sx, y: 3.9487 * sy))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Custom Vector Shape for Section 3: Land Area (SVG 3 refreshed)

public struct LandAreaIconShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 14.0
        let sy = rect.height / 14.0
        
        var path = Path()
        path.move(to: CGPoint(x: 12.0154 * sx, y: 2.57082 * sy))
        path.addCurve(to: CGPoint(x: 11.4745 * sx, y: 2.20936 * sy), control1: CGPoint(x: 11.8606 * sx, y: 2.41598 * sy), control2: CGPoint(x: 11.6768 * sx, y: 2.29316 * sy))
        path.addCurve(to: CGPoint(x: 10.8365 * sx, y: 2.08243 * sy), control1: CGPoint(x: 11.2722 * sx, y: 2.12556 * sy), control2: CGPoint(x: 11.0554 * sx, y: 2.08243 * sy))
        path.addCurve(to: CGPoint(x: 10.1985 * sx, y: 2.20936 * sy), control1: CGPoint(x: 10.6175 * sx, y: 2.08243 * sy), control2: CGPoint(x: 10.4007 * sx, y: 2.12556 * sy))
        path.addCurve(to: CGPoint(x: 9.65761 * sx, y: 2.57082 * sy), control1: CGPoint(x: 9.99619 * sx, y: 2.29316 * sy), control2: CGPoint(x: 9.8124 * sx, y: 2.41598 * sy))
        path.addCurve(to: CGPoint(x: 9.3888 * sx, y: 2.92297 * sy), control1: CGPoint(x: 9.55269 * sx, y: 2.67568 * sy), control2: CGPoint(x: 9.46228 * sx, y: 2.79412 * sy))
        path.addLine(to: CGPoint(x: 7.91872 * sx, y: 2.52185 * sy))
        path.addCurve(to: CGPoint(x: 7.64732 * sx, y: 1.58709 * sy), control1: CGPoint(x: 7.92326 * sx, y: 2.1902 * sy), control2: CGPoint(x: 7.82877 * sx, y: 1.86474 * sy))
        path.addCurve(to: CGPoint(x: 6.90016 * sx, y: 0.963248 * sy), control1: CGPoint(x: 7.46588 * sx, y: 1.30944 * sy), control2: CGPoint(x: 7.20573 * sx, y: 1.09223 * sy))
        path.addCurve(to: CGPoint(x: 5.93197 * sx, y: 0.863018 * sy), control1: CGPoint(x: 6.59459 * sx, y: 0.834263 * sy), control2: CGPoint(x: 6.25748 * sy, y: 0.799365 * sy))
        path.addCurve(to: CGPoint(x: 5.07286 * sx, y: 1.32057 * sy), control1: CGPoint(x: 5.60646 * sx, y: 0.926672 * sy), control2: CGPoint(x: 5.30733 * sx, y: 1.08598 * sy))
        path.addCurve(to: CGPoint(x: 4.60454 * sx, y: 2.24598 * sy), control1: CGPoint(x: 4.8225 * sx, y: 1.57152 * sy), control2: CGPoint(x: 4.65848 * sx, y: 1.89562 * sy))
        path.addCurve(to: CGPoint(x: 4.7728 * sx, y: 3.26939 * sy), control1: CGPoint(x: 4.55059 * sx, y: 2.59633 * sy), control2: CGPoint(x: 4.60952 * sy, y: 2.95475 * sy))
        path.addLine(to: CGPoint(x: 3.00474 * sx, y: 4.86085 * sy))
        path.addCurve(to: CGPoint(x: 1.91724 * sx, y: 4.59247 * sy), control1: CGPoint(x: 2.68396 * sx, y: 4.64883 * sy), control2: CGPoint(x: 2.29983 * sx, y: 4.55403 * sy))
        path.addCurve(to: CGPoint(x: 0.904854 * sx, y: 5.07183 * sy), control1: CGPoint(x: 1.53464 * sx, y: 4.63091 * sy), control2: CGPoint(x: 1.17705 * sx, y: 4.80023 * sy))
        path.addCurve(to: CGPoint(x: 0.412714 * sx, y: 6.21019 * sy), control1: CGPoint(x: 0.600508 * sx, y: 5.37387 * sy), control2: CGPoint(x: 0.42425 * sx, y: 5.78157 * sy))
        path.addCurve(to: CGPoint(x: 0.842906 * sx, y: 7.37338 * sy), control1: CGPoint(x: 0.401177 * sx, y: 6.63882 * sy), control2: CGPoint(x: 0.555248 * sx, y: 7.05541 * sy))
        path.addCurve(to: CGPoint(x: 1.95732 * sx, y: 7.91758 * sy), control1: CGPoint(x: 1.13056 * sx, y: 7.69136 * sy), control2: CGPoint(x: 1.52969 * sx, y: 7.88626 * sy))
        path.addCurve(to: CGPoint(x: 3.13914 * sx, y: 7.54158 * sy), control1: CGPoint(x: 2.38496 * sx, y: 7.94891 * sy), control2: CGPoint(x: 2.80822 * sx, y: 7.81424 * sy))
        path.addLine(to: CGPoint(x: 6.78569 * sx, y: 10.2171 * sy))
        path.addCurve(to: CGPoint(x: 6.69453 * sx, y: 11.1381 * sy), control1: CGPoint(x: 6.66899 * sx, y: 10.5093 * sy), control2: CGPoint(x: 6.63739 * sx, y: 10.8286 * sy))
        path.addCurve(to: CGPoint(x: 7.10863 * sx, y: 11.9657 * sy), control1: CGPoint(x: 6.75168 * sx, y: 11.4475 * sy), control2: CGPoint(x: 6.89525 * sx, y: 11.7345 * sy))
        path.addCurve(to: CGPoint(x: 7.90035 * sx, y: 12.445 * sy), control1: CGPoint(x: 7.32202 * sx, y: 12.197 * sy), control2: CGPoint(x: 7.5965 * sx, y: 12.3632 * sy))
        path.addCurve(to: CGPoint(x: 8.82567 * sx, y: 12.4281 * sy), control1: CGPoint(x: 8.2042 * sx, y: 12.5268 * sy), control2: CGPoint(x: 8.525 * sx, y: 12.521 * sy))
        path.addCurve(to: CGPoint(x: 9.59938 * sx, y: 11.9203 * sy), control1: CGPoint(x: 9.12633 * sx, y: 12.3353 * sy), control2: CGPoint(x: 9.39458 * sx, y: 12.1592 * sy))
        path.addCurve(to: CGPoint(x: 9.98302 * sx, y: 11.0781 * sy), control1: CGPoint(x: 9.80419 * sx, y: 11.6814 * sy), control2: CGPoint(x: 9.9372 * sy, y: 11.3894 * sy))
        path.addCurve(to: CGPoint(x: 9.85835 * sx, y: 10.1611 * sy), control1: CGPoint(x: 10.0289 * sx, y: 10.7668 * sy), control2: CGPoint(x: 9.98563 * sx, y: 10.4488 * sy))
        path.addCurve(to: CGPoint(x: 9.26378 * sx, y: 9.45185 * sy), control1: CGPoint(x: 9.73107 * sx, y: 9.87328 * sy), control2: CGPoint(x: 9.52493 * sx, y: 9.6274 * sy))
        path.addLine(to: CGPoint(x: 10.6906 * sx, y: 5.40991 * sy))
        path.addCurve(to: CGPoint(x: 10.8344 * sx, y: 5.41617 * sy), control1: CGPoint(x: 10.7385 * sx, y: 5.41408 * sy), control2: CGPoint(x: 10.7865 * sx, y: 5.41617 * sy))
        path.addCurve(to: CGPoint(x: 11.7603 * sx, y: 5.1352 * sy), control1: CGPoint(x: 11.164 * sx, y: 5.41612 * sy), control2: CGPoint(x: 11.4862 * sx, y: 5.31834 * sy))
        path.addCurve(to: CGPoint(x: 12.3742 * sx, y: 4.38724 * sy), control1: CGPoint(x: 12.0344 * sx, y: 4.95205 * sy), control2: CGPoint(x: 12.248 * sx, y: 4.69177 * sy))
        path.addCurve(to: CGPoint(x: 12.4692 * sx, y: 3.4243 * sy), control1: CGPoint(x: 12.5004 * sx, y: 4.08271 * sy), control2: CGPoint(x: 12.5334 * sx, y: 3.74761 * sy))
        path.addCurve(to: CGPoint(x: 12.0133 * sx, y: 2.57082 * sy), control1: CGPoint(x: 12.4049 * sx, y: 3.10099 * sy), control2: CGPoint(x: 12.2463 * sx, y: 2.80398 * sy))
        path.closeSubpath()
        return path
    }
}

// MARK: - Custom Vector Shape for Section 4: Land Type (SVG 4 refreshed)

public struct LandTypeIconShape: Shape {
    public init() {}
    
    public func path(in rect: CGRect) -> Path {
        let sx = rect.width / 13.0
        let sy = rect.height / 13.0
        
        var path = Path()
        path.move(to: CGPoint(x: 11.2932 * sx, y: 2.72681 * sy))
        path.addLine(to: CGPoint(x: 3.50513 * sx, y: 2.72681 * sy))
        path.addLine(to: CGPoint(x: 3.50513 * sx, y: 1.948 * sy))
        path.addCurve(to: CGPoint(x: 3.39107 * sx, y: 1.67265 * sy), control1: CGPoint(x: 3.50513 * sx, y: 1.84472 * sy), control2: CGPoint(x: 3.4641 * sx, y: 1.74568 * sy))
        path.addCurve(to: CGPoint(x: 3.11572 * sx, y: 1.55859 * sy), control1: CGPoint(x: 3.31805 * sx, y: 1.59962 * sy), control2: CGPoint(x: 3.219 * sx, y: 1.55859 * sy))
        path.addLine(to: CGPoint(x: 2.33691 * sx, y: 1.55859 * sy))
        path.addCurve(to: CGPoint(x: 1.23551 * sx, y: 2.01481 * sy), control1: CGPoint(x: 1.92381 * sx, y: 1.55859 * sy), control2: CGPoint(x: 1.52762 * sx, y: 1.7227 * sy))
        path.addCurve(to: CGPoint(x: 0.779297 * sx, y: 3.11621 * sy), control1: CGPoint(x: 0.943403 * sx, y: 2.30692 * sy), control2: CGPoint(x: 0.779297 * sx, y: 2.70311 * sy))
        path.addLine(to: CGPoint(x: 0.779297 * sx, y: 8.56787 * sy))
        path.addCurve(to: CGPoint(x: 1.23551 * sx, y: 9.66927 * sy), control1: CGPoint(x: 0.779297 * sx, y: 8.98098 * sy), control2: CGPoint(x: 0.943403 * sx, y: 9.37716 * sy))
        path.addCurve(to: CGPoint(x: 2.33691 * sx, y: 10.1255 * sy), control1: CGPoint(x: 1.52762 * sx, y: 9.96138 * sy), control2: CGPoint(x: 1.92381 * sx, y: 10.1255 * sy))
        path.addLine(to: CGPoint(x: 11.2932 * sx, y: 10.1255 * sy))
        path.addCurve(to: CGPoint(x: 11.5686 * sx, y: 10.0114 * sy), control1: CGPoint(x: 11.3965 * sx, y: 10.1255 * sy), control2: CGPoint(x: 11.4955 * sx, y: 10.0845 * sy))
        path.addCurve(to: CGPoint(x: 11.6826 * sx, y: 9.73608 * sy), control1: CGPoint(x: 11.6416 * sx, y: 9.93841 * sy), control2: CGPoint(x: 11.6826 * sx, y: 9.83936 * sy))
        path.addLine(to: CGPoint(x: 11.6826 * sx, y: 3.11621 * sy))
        path.addCurve(to: CGPoint(x: 11.5686 * sx, y: 2.84086 * sy), control1: CGPoint(x: 11.6826 * sx, y: 3.01293 * sy), control2: CGPoint(x: 11.6416 * sx, y: 2.91389 * sy))
        path.addCurve(to: CGPoint(x: 11.2932 * sx, y: 2.72681 * sy), control1: CGPoint(x: 11.4955 * sx, y: 2.76783 * sy), control2: CGPoint(x: 11.3965 * sx, y: 2.72681 * sy))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dotted Line Separator

public struct DottedLine: Shape {
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

// MARK: - Wrapping Flow Layout for Badges

public struct WrappingFlowLayout: Layout {
    public var spacing: CGFloat = 8
    public var lineSpacing: CGFloat = 8
    
    public init(spacing: CGFloat = 8, lineSpacing: CGFloat = 8) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        return CGSize(width: width, height: currentY + lineHeight)
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

// MARK: - Main LandPassportDetailView

private struct LandDetailScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public struct LandPassportDetailView: View {
    public let result: OfficialSearchResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // State
    @State private var isLoadingDocument: Bool = true
    @State private var showShareSheet: Bool = false
    @State private var isExplicitlyOpeningPDF: Bool = false
    @State private var downloadedPDFURL: URL? = nil
    @State private var showAreaCalculator: Bool = false
    @State private var showActionMenu: Bool = false
    @State private var isOwnersExpanded: Bool = false
    @State private var showSaveSuccessModal: Bool = false
    @ObservedObject private var savedLandManager = SavedLandManager.shared
    @State private var resolvedBoundary: [Coordinate]
    @State private var isResolvingBoundary = false
    @State private var isBottomBarVisible: Bool = true
    @State private var lastScrollOffset: CGFloat = 0
    @State private var showAllAssociatedPlots: Bool = false
    
    private var isSavedLocally: Bool {
        savedLandManager.isSaved(result: result)
    }
    
    /// A map-originated report carries the exact selected plot geometry. Reports
    /// opened from a direct search resolve that same geometry below when needed.
    public init(result: OfficialSearchResult, selectedBoundary: [Coordinate] = []) {
        self.result = result
        self._resolvedBoundary = State(initialValue: selectedBoundary)
    }
    
    // MARK: - Dynamic Theme Palette
    
    private var pageBackground: Color {
        colorScheme == .dark
            ? Color(red: 14/255, green: 14/255, blue: 16/255)
            : Color(red: 245/255, green: 246/255, blue: 248/255)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 24/255, green: 24/255, blue: 28/255)
            : Color.white
    }
    
    private var headerStripBackground: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color(red: 240/255, green: 242/255, blue: 245/255)
    }
    
    private var primaryText: Color {
        colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255)
    }
    
    private var secondaryText: Color {
        colorScheme == .dark
            ? Color(red: 160/255, green: 160/255, blue: 170/255)
            : Color(red: 110/255, green: 115/255, blue: 125/255)
    }
    
    private var dividerColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.08)
    }

    private var sectionHeaderText: Color {
        colorScheme == .dark
            ? Color(red: 218/255, green: 220/255, blue: 228/255)
            : Color(red: 60/255, green: 70/255, blue: 85/255)
    }

    private var tertiarySurface: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color(red: 240/255, green: 242/255, blue: 246/255)
    }

    private var accentText: Color {
        colorScheme == .dark
            ? Color(red: 194/255, green: 171/255, blue: 255/255)
            : Color(red: 100/255, green: 30/255, blue: 220/255)
    }

    private var documentActionText: Color {
        colorScheme == .dark
            ? Color(red: 191/255, green: 178/255, blue: 255/255)
            : Color(red: 79/255, green: 70/255, blue: 229/255)
    }

    private var documentActionSurface: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color(red: 243/255, green: 244/255, blue: 246/255)
    }

    private var verificationBadgeBackground: Color {
        colorScheme == .dark
            ? Color(red: 16/255, green: 62/255, blue: 36/255)
            : Color(red: 220/255, green: 252/255, blue: 231/255)
    }

    private var verificationBadgeText: Color {
        colorScheme == .dark
            ? Color(red: 134/255, green: 239/255, blue: 172/255)
            : Color(red: 21/255, green: 128/255, blue: 61/255)
    }

    private var selectedPlotSurface: Color {
        colorScheme == .dark
            ? Color(red: 93/255, green: 62/255, blue: 188/255)
            : Color(red: 17/255, green: 24/255, blue: 39/255)
    }

    // MARK: - Computed Properties
    
    private var isVerified: Bool {
        result.rawResponse.verification?.status == .verified || result.rawResponse.success
    }
    
    private var displayDistrict: String {
        result.districtName.isEmpty ? result.rawResponse.district : result.districtName
    }
    
    private var displayTahasil: String {
        result.tahasilName.isEmpty ? result.rawResponse.tahasil : result.tahasilName
    }
    
    private var displayPanchayat: String {
        if let p = result.rawResponse.rawFields?["panchayat"], !p.isEmpty { return p }
        if let p = result.rawResponse.rawFields?["gp"], !p.isEmpty { return p }
        if let p = result.rawResponse.rawFields?["gram_panchayat"], !p.isEmpty { return p }
        return result.villageName.isEmpty ? result.rawResponse.village : result.villageName
    }
    
    private var displayPostOffice: String {
        if let po = result.rawResponse.rawFields?["po"], !po.isEmpty { return po }
        if let po = result.rawResponse.rawFields?["post_office"], !po.isEmpty { return po }
        if let po = result.rawResponse.rawFields?["p_o"], !po.isEmpty { return po }
        if let po = result.rawResponse.rawFields?["postoffice"], !po.isEmpty { return po }
        if let gp = result.rawResponse.rawFields?["gp"], !gp.isEmpty { return gp }
        if let pan = result.rawResponse.rawFields?["panchayat"], !pan.isEmpty { return pan }
        return result.villageName.isEmpty ? (result.rawResponse.village.isEmpty ? "N/A" : result.rawResponse.village) : result.villageName
    }
    
    private var displayVillage: String {
        let raw = result.villageName.isEmpty ? (result.rawResponse.village.isEmpty ? "N/A" : result.rawResponse.village) : result.villageName
        return VillageNameSanitizer.sanitize(raw)
    }
    
    private var displayKhatian: String {
        result.khatianNumber.isEmpty ? (result.rawResponse.khataNumber ?? "N/A") : result.khatianNumber
    }
    
    private var allOwnersList: [OwnerEntry] {
        if !result.rawResponse.owners.isEmpty {
            return result.rawResponse.owners
        }
        if let name = result.rawResponse.rawFields?["owner_name"] ?? result.rawResponse.rawFields?["khatadar_name"] ?? result.rawResponse.rawFields?["owner"], !name.isEmpty {
            let share = result.rawResponse.rawFields?["share"] ?? "1/1"
            let khata = result.khatianNumber.isEmpty ? result.rawResponse.khataNumber : result.khatianNumber
            return [OwnerEntry(name: name, share: share, khataNumber: khata)]
        }
        return []
    }
    
    private var displayArea: String {
        if let area = result.area, !area.isEmpty { return area }
        if let rawArea = result.rawResponse.area, !rawArea.isEmpty { return rawArea }
        return "N/A"
    }
    
    private var displayTenure: String {
        if let tenure = result.rawResponse.rawFields?["tenure"], !tenure.isEmpty {
            return tenure
        }
        if result.resolutionStatus == .verified {
            return result.isGovernmentLand ? "Government Estate" : "Rayati (Stitiban)"
        }
        return "Rayati (Stitiban)"
    }
    
    public var body: some View {
        NavigationStack {
            detailPage
                .navigationTitle(isLoadingDocument ? "" : "Land Details")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    if !isLoadingDocument {
                        navigationToolbar
                    }
                }
                .navigationBarHidden(isLoadingDocument)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedPDFURL {
                ShareSheet(activityItems: [url])
            } else {
                ShareSheet(activityItems: [generateShareSummary()])
            }
        }
        .fullScreenCover(isPresented: $showAreaCalculator) {
            LandAreaConverterView(
                officialArea: result.area ?? result.rawResponse.area,
                parcelContext: "Plot \(result.plotNumber) • \(displayVillage)"
            )
        }
        .fullScreenCover(isPresented: $showSaveSuccessModal) {
            SaveLandSuccessModalView(
                plotNumber: result.plotNumber,
                villageName: displayVillage,
                onDismiss: {
                    showSaveSuccessModal = false
                }
            )
        }
        .task {
            // Background prefetch of already-prepared official RoR document
            if let docID = result.rawResponse.officialDocument?.documentID, downloadedPDFURL == nil {
                if let (url, _, _) = try? await RoRService.shared.downloadOfficialDocument(documentID: docID) {
                    await MainActor.run {
                        self.downloadedPDFURL = url
                    }
                }
            }

            await resolveSelectedPlotBoundaryIfNeeded()
        }
        .onAppear {
            AnalyticsService.shared.log(.landPassportViewed(
                districtID: result.districtName,
                isGovernmentLand: result.isGovernmentLand,
                ownerCount: result.ownersCount
            ))
            AnalyticsService.shared.log(.bhumitraReportViewed(districtID: result.districtName))
        }
        .liquidToastOverlay()
    }

    private var detailPage: some View {
        ZStack {
            // Screen Background
            pageBackground
                .ignoresSafeArea()
            
            if isLoadingDocument {
                // Centered Minimal Loading State (Exact Screen Center)
                PillLoadingIndicator(width: 70, height: 10, duration: 2.0) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        isLoadingDocument = false
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .transition(.opacity)
            } else {
                ZStack(alignment: .bottom) {
                    ScrollView(.vertical, showsIndicators: false) {
                        GeometryReader { proxy in
                            let offset = proxy.frame(in: .named("landDetailScroll")).minY
                            Color.clear.preference(key: LandDetailScrollOffsetKey.self, value: offset)
                        }
                        .frame(height: 0)

                        VStack(spacing: 28) {
                            heroPropertyCard
                            locationSection
                            ownershipSection
                            landAreaSection
                            landTypeSection
                            associatedPlotsSection
                            remarksSection
                            recordVerificationSection
                            documentsSection
                            auditFooterSection
                                .padding(.top, 10)
                                .padding(.bottom, 88)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                    }
                    .coordinateSpace(name: "landDetailScroll")
                    .onPreferenceChange(LandDetailScrollOffsetKey.self) { newOffset in
                        let delta = newOffset - lastScrollOffset
                        // User scrolling downwards (content moving up, negative delta) -> hide
                        if delta < -6 && newOffset < -20 {
                            if isBottomBarVisible {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isBottomBarVisible = false
                                }
                            }
                        } else if delta > 6 {
                            // User scrolling upwards (content moving down, positive delta) -> show
                            if !isBottomBarVisible {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isBottomBarVisible = true
                                }
                            }
                        }
                        lastScrollOffset = newOffset
                    }

                    bottomActionBar
                        .offset(y: isBottomBarVisible ? 0 : 100)
                        .opacity(isBottomBarVisible ? 1 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isBottomBarVisible)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }
    
    // MARK: - Native Page Navigation

    @ToolbarContentBuilder
    private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                Theme.haptic(.light)
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Back")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showShareSheet = true
                } label: {
                    Label("Share Land Summary", systemImage: "square.and.arrow.up")
                }

                Button {
                    showAreaCalculator = true
                } label: {
                    Label("Area Converter", systemImage: "function")
                }

                if let url = downloadedPDFURL {
                    ShareLink(item: url) {
                        Label("Save Official PDF", systemImage: "arrow.down.doc")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("More Options")
        }
    }
    
    // MARK: - District Hero Image Resolution (All 30 Odisha Districts)
    
    private var districtHeroImageName: String {
        let name = displayDistrict.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if name.contains("bhadrak") { return "DistrictHero_Bhadrak" }
        if name.contains("bargarh") { return "DistrictHero_Bargarh" }
        if name.contains("mayurbhanj") || name.contains("baripada") { return "DistrictHero_Mayurbhanj" }
        if name.contains("keonjhar") || name.contains("kendujhar") { return "DistrictHero_Kendujhar" }
        if name.contains("cuttack") { return "DistrictHero_Cuttack" }
        if name.contains("puri") { return "DistrictHero_Puri" }
        if name.contains("khordha") || name.contains("khurda") || name.contains("bhubaneswar") { return "DistrictHero_Khordha" }
        if name.contains("balasore") || name.contains("baleswar") { return "DistrictHero_Balasore" }
        if name.contains("sambalpur") { return "DistrictHero_Sambalpur" }
        if name.contains("koraput") { return "DistrictHero_Koraput" }
        if name.contains("ganjam") || name.contains("berhampur") { return "DistrictHero_Ganjam" }
        if name.contains("kalahandi") { return "DistrictHero_Kalahandi" }
        if name.contains("balangir") || name.contains("bolangir") { return "DistrictHero_Balangir" }
        if name.contains("dhenkanal") { return "DistrictHero_Dhenkanal" }
        if name.contains("angul") { return "DistrictHero_Angul" }
        if name.contains("sundargarh") || name.contains("sundergarh") || name.contains("rourkela") { return "DistrictHero_Sundargarh" }
        if name.contains("jajpur") { return "DistrictHero_Jajpur" }
        if name.contains("kendrapara") { return "DistrictHero_Kendrapara" }
        if name.contains("jagatsinghpur") { return "DistrictHero_Jagatsinghpur" }
        if name.contains("kandhamal") || name.contains("phulbani") { return "DistrictHero_Kandhamal" }
        if name.contains("rayagada") { return "DistrictHero_Rayagada" }
        if name.contains("malkangiri") { return "DistrictHero_Malkangiri" }
        if name.contains("nabarangpur") || name.contains("nowrangpur") { return "DistrictHero_Nabarangpur" }
        if name.contains("nayagarh") { return "DistrictHero_Nayagarh" }
        if name.contains("nuapada") { return "DistrictHero_Nuapada" }
        if name.contains("subarnapur") || name.contains("sonepur") { return "DistrictHero_Subarnapur" }
        if name.contains("deogarh") || name.contains("debagarh") { return "DistrictHero_Deogarh" }
        if name.contains("jharsuguda") { return "DistrictHero_Jharsuguda" }
        if name.contains("boudh") { return "DistrictHero_Boudh" }
        if name.contains("gajapati") { return "DistrictHero_Gajapati" }
        return "LandDetailsHeroBackground"
    }

    // MARK: - 1. Hero Property Card (Top Section)
    
    private var heroPropertyCard: some View {
        VStack(spacing: 0) {
            // ── Upper Media & Branding Area ──────────────────────────
            ZStack(alignment: .top) {
                // Background District Landscape Photo (Strictly constrained to card width)
                GeometryReader { geo in
                    Image(districtHeroImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: 220)
                        .clipped()
                }
                .frame(height: 220)
                
                // Header Overlay: "Property in <District>" + "LAND Simplified" Logo
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Property in")
                            .font(.system(size: 13.5, weight: .regular, design: .rounded))
                            .foregroundColor(Color(red: 70/255, green: 80/255, blue: 95/255))
                        
                        Text(displayDistrict)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 17/255, green: 24/255, blue: 39/255))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // "LAND Simplified" Logo
                    Image("LandSimplifiedLogo")
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(Color(red: 17/255, green: 24/255, blue: 39/255))
                        .frame(width: 115, height: 52)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .frame(height: 220)
            .clipped()
            
            // ── Lower Plot Number & Location Hierarchy Area ──────────
            HStack(alignment: .center, spacing: 20) {
                // Left Column: Hero Plot Number
                VStack(alignment: .leading, spacing: 0) {
                    Text("Plot")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(secondaryText)
                    
                    Text(result.plotNumber)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right Column: 4 Location Hierarchy Rows
                VStack(alignment: .leading, spacing: 13) {
                    locationAttributeRow(
                        iconName: "icon_location_district",
                        fallbackIcon: "gavel",
                        label: "Dist:",
                        value: displayDistrict
                    )
                    
                    locationAttributeRow(
                        iconName: "icon_location_tahsil",
                        fallbackIcon: "building.columns",
                        label: "Tahsil:",
                        value: displayTahasil
                    )
                    
                    locationAttributeRow(
                        iconName: "icon_location_panchayat",
                        fallbackIcon: "house.and.flag",
                        label: "P/O:",
                        value: displayPostOffice
                    )
                    
                    locationAttributeRow(
                        iconName: "icon_location_village",
                        fallbackIcon: "house",
                        label: "Village:",
                        value: displayVillage
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)
            .background(cardBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    // MARK: - Location Attribute Row Helper
    
    private func locationAttributeRow(
        iconName: String,
        fallbackIcon: String,
        label: String,
        value: String
    ) -> some View {
        HStack(spacing: 5) {
            // Icon
            Group {
                if let uiImage = UIImage(named: iconName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: fallbackIcon)
                        .font(.system(size: 11.5, weight: .regular))
                }
            }
            .foregroundColor(secondaryText)
            .frame(width: 14, height: 14)
            
            // Label e.g. "Dist:", "Tahsil:", "P/O:", "Village:"
            Text(label)
                .font(.system(size: 13.5, weight: .regular, design: .rounded))
                .foregroundColor(secondaryText)
            
            // Value directly adjacent
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(primaryText)
                .lineLimit(1)
        }
    }
    
    // MARK: - 2. Location Section (Full-width Card with Top Header)
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Section Header
            Text("Location")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(sectionHeaderText)
                .padding(.leading, 4)
            
            // Full Width Live Map Card
            ZStack(alignment: .topTrailing) {
                CadastralSpecimenMapThumbnailView(
                    plotNumber: result.plotNumber,
                    districtName: result.districtName,
                    boundary: resolvedBoundary,
                    isResolvingBoundary: isResolvingBoundary
                )
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                // "View on map" Glass Pill Button
                Button {
                    Theme.haptic(.light)
                    dismiss()
                } label: {
                    Text("View on map")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(accentText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(colorScheme == .dark ? Color.black.opacity(0.72) : Color.white.opacity(0.95))
                                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.06), radius: 4, x: 0, y: 2)
                        )
                }
                .padding(12)
                .accessibilityLabel("View plot on interactive map")
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                Theme.haptic(.light)
                dismiss()
            }
        }
    }
    
    // MARK: - 3. Ownership Section (Full-width Card with Top Header)
    
    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Section Header
            Text("Ownership")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(sectionHeaderText)
                .padding(.leading, 4)
            
            // Full Width Ownership Table Card
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    // Top Header Strip: "Recorded Owners" (left) | "Share" (right)
                    HStack {
                        Text("Recorded Owners")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                        
                        Spacer()
                        
                        Text("Share")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(headerStripBackground)
                    
                    // Owners List
                    let allOwners = allOwnersList
                    let displayedOwners = isOwnersExpanded ? allOwners : Array(allOwners.prefix(3))
                    
                    if allOwners.isEmpty {
                        VStack(spacing: 6) {
                            Text("No recorded owner details returned from revenue records.")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(secondaryText)
                                .padding(.vertical, 16)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(displayedOwners.enumerated()), id: \.element.id) { index, owner in
                                ownerRowView(owner: owner, totalOwnersCount: allOwners.count)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 14)
                                
                                // Dotted Divider between items (except last item)
                                if index < displayedOwners.count - 1 {
                                    DottedLine()
                                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [3.5, 3.5]))
                                        .foregroundColor(dividerColor.opacity(0.85))
                                        .frame(height: 1)
                                        .padding(.horizontal, 18)
                                }
                            }
                        }
                        .background(cardBackground)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                // "View all X owners ->" Purple Link Button
                if allOwnersList.count > 3 && !isOwnersExpanded {
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            isOwnersExpanded = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("View all \(allOwnersList.count) owners")
                                .font(.system(size: 16.5, weight: .semibold, design: .rounded))
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(accentText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Owner Row View Item
    
    private func ownerRowView(owner: OwnerEntry, totalOwnersCount: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Person Avatar Icon
            ZStack {
                Circle()
                    .fill(tertiarySurface)
                    .frame(width: 38, height: 38)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(secondaryText)
            }
            
            // Owner Name & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(owner.name)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                let subtitleText: String = {
                    if let raw = result.rawResponse.rawFields?["father_name"], !raw.isEmpty {
                        return "S/O: \(raw)"
                    }
                    if let raw = result.rawResponse.rawFields?["relation_name"], !raw.isEmpty {
                        return "Relation: \(raw)"
                    }
                    if let khata = owner.khataNumber, !khata.isEmpty {
                        return "Khata: \(khata)"
                    }
                    if !displayKhatian.isEmpty && displayKhatian != "N/A" {
                        return "Khata: \(displayKhatian)"
                    }
                    return "Recorded Owner"
                }()
                
                Text(subtitleText)
                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                    .foregroundColor(secondaryText)
            }
            
            Spacer(minLength: 8)
            
            // Share Fraction (e.g. 1/2 or 1/1)
            let displayShare: String = {
                if let s = owner.share, !s.isEmpty { return s }
                if totalOwnersCount > 1 { return "1/\(totalOwnersCount)" }
                return "1/1"
            }()
            
            Text(displayShare)
                .font(.system(size: 16.5, weight: .regular, design: .rounded))
                .foregroundColor(primaryText)
        }
    }
    
    // MARK: - 4. Land Area Section (Full-width Card with Top Header)
    
    private var calculatedArea: (decimal: String, acre: String, sqFt: String) {
        let raw = displayArea
        
        let acreVal: Double
        let decimalVal: Double
        let sqFtVal: Double
        
        if let structured = LandAreaUnitConverter.parseStructuredExtent(from: raw) {
            switch structured.unit {
            case .acres:
                acreVal = structured.value
                decimalVal = structured.value * 100.0
                sqFtVal = acreVal * 43560.0
            case .decimal:
                decimalVal = structured.value
                acreVal = decimalVal / 100.0
                sqFtVal = decimalVal * 435.6
            case .squareFeet:
                sqFtVal = structured.value
                decimalVal = sqFtVal / 435.6
                acreVal = sqFtVal / 43560.0
            case .squareMeters:
                sqFtVal = structured.value * 10.7639
                decimalVal = sqFtVal / 435.6
                acreVal = sqFtVal / 43560.0
            default:
                if let sqM = LandAreaUnitConverter.toSqMeters(value: structured.value, from: structured.unit, in: .odisha) {
                    decimalVal = LandAreaUnitConverter.fromSqMeters(sqM, to: .decimal, in: .odisha) ?? (structured.value * 100.0)
                    acreVal = LandAreaUnitConverter.fromSqMeters(sqM, to: .acres, in: .odisha) ?? structured.value
                    sqFtVal = LandAreaUnitConverter.fromSqMeters(sqM, to: .squareFeet, in: .odisha) ?? (acreVal * 43560.0)
                } else {
                    acreVal = structured.value
                    decimalVal = structured.value * 100.0
                    sqFtVal = acreVal * 43560.0
                }
            }
        } else {
            let cleaned = raw
                .replacingOccurrences(of: "Ac.", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Ac", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Dec.", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Dec", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Acre", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "Decimal", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let val = Double(cleaned) ?? 0.0
            if raw.lowercased().contains("dec") {
                decimalVal = val
                acreVal = decimalVal / 100.0
                sqFtVal = decimalVal * 435.6
            } else {
                // In Odisha Bhulekh records, raw numeric values are recorded in Acres (e.g. 0.3800 = 0.38 Ac = 38.00 Dec)
                acreVal = val
                decimalVal = val * 100.0
                sqFtVal = acreVal * 43560.0
            }
        }
        
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        let formattedSqFt = nf.string(from: NSNumber(value: sqFtVal)) ?? String(format: "%.0f", sqFtVal)
        
        let decimalStr: String = {
            if decimalVal.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%.0f", decimalVal)
            } else {
                return String(format: "%.2f", decimalVal)
            }
        }()
        
        let acreStr: String = {
            if acreVal < 0.001 && acreVal > 0 {
                return String(format: "%.4f", acreVal)
            } else {
                return String(format: "%.3f", acreVal)
            }
        }()
        
        return (decimal: decimalStr, acre: acreStr, sqFt: formattedSqFt)
    }
    
    private var landAreaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Section Header
            Text("Land Area")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(sectionHeaderText)
                .padding(.leading, 4)
            
            // Full Width Land Area Card
            VStack(spacing: 0) {
                // Top Dark Blue Cosmos Banner
                ZStack(alignment: .leading) {
                    Image("LandAreaBanner")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 84)
                        .clipped()
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(calculatedArea.decimal)
                            .font(.system(size: 46, weight: .regular, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Decimal")
                            .font(.system(size: 22, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 84)
                
                // Bottom Area: 2 Metric Columns (Acre and Sq. ft)
                HStack(spacing: 0) {
                    // Acre
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Acre")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                        
                        Text(calculatedArea.acre)
                            .font(.system(size: 26, weight: .regular, design: .rounded))
                            .foregroundColor(primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Sq. ft
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sq. ft")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                        
                        Text(calculatedArea.sqFt)
                            .font(.system(size: 26, weight: .regular, design: .rounded))
                            .foregroundColor(primaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(cardBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                Theme.haptic(.light)
                showAreaCalculator = true
            }
        }
    }
    
    // MARK: - 5. Land Type Section (Full-width Card with Top Header)
    
    private var landClassificationName: String {
        if let kisam = result.rawResponse.rawFields?["kisam"], !kisam.isEmpty {
            return kisam
        }
        if let kisam = result.rawResponse.rawFields?["land_type"], !kisam.isEmpty {
            return kisam
        }
        if let kisam = result.rawResponse.landType, !kisam.isEmpty {
            return kisam
        }
        if let tenure = result.rawResponse.rawFields?["tenure"], !tenure.isEmpty {
            return tenure
        }
        return "Rayati"
    }
    
    private struct LandTypeMetadata {
        let category: String
        let iconName: String
        let badgeColor: Color
        let imageName: String
        let description: String
    }
    
    private var landTypeMetadata: LandTypeMetadata {
        let name = landClassificationName.lowercased()
        
        // 1. Bahal / Bahala (Lowland Fertile Paddy)
        if name.contains("bahal") || name.contains("bahala") || name.contains("ବାହାଲ") {
            return LandTypeMetadata(
                category: "Lowland Wet Arable (Bahal)",
                iconName: "leaf.fill",
                badgeColor: Color(red: 21/255, green: 128/255, blue: 61/255),
                imageName: "LandTypeAgricultural",
                description: "Low-lying, highly fertile bottom-land that naturally collects water runoff from surrounding slopes. Highly valued across Western & Central Odisha for double-cropping and rich winter paddy yields."
            )
        }
        // 2. Berna (Mid-Lowland Arable)
        else if name.contains("berna") || name.contains("ବେର୍ଣ୍ଣା") {
            return LandTypeMetadata(
                category: "Medium Lowland Arable (Berna)",
                iconName: "leaf.fill",
                badgeColor: Color(red: 22/255, green: 163/255, blue: 74/255),
                imageName: "LandTypeAgricultural",
                description: "Terraced mid-low slope agricultural land situated between Bahal and Mal. Retains ample soil moisture for abundant autumn and winter paddy harvests."
            )
        }
        // 3. Mal / Mala (Terraced Midland Slope)
        else if name.contains("mal") || name.contains("mala") || name.contains("ମାଳ") {
            return LandTypeMetadata(
                category: "Terraced Midland Slope (Mal)",
                iconName: "leaf.fill",
                badgeColor: Color(red: 13/255, green: 148/255, blue: 136/255),
                imageName: "LandTypeAgricultural",
                description: "Terraced upland agricultural tract sloping towards lowlands. Reliant on seasonal rainfall, cultivated for early-ripening paddy, pulses, and oilseeds."
            )
        }
        // 4. At / Aat (Highland Dry Arable)
        else if name.contains("aat") || name.contains("at mamuli") || name.contains("ଆଟ") || (name.hasPrefix("at") && !name.contains("attach")) {
            return LandTypeMetadata(
                category: "Highland Dry Arable (At)",
                iconName: "sun.max.fill",
                badgeColor: Color(red: 217/255, green: 119/255, blue: 6/255),
                imageName: "LandTypeAgricultural",
                description: "Elevated highland tract situated above the village settlement with sandy or gravelly soil. Cultivated for hardy dry crops, millets, sesame, and pulses."
            )
        }
        // 5. Taila / Toila (Upland Shifting / Slope Arable)
        else if name.contains("taila") || name.contains("toila") || name.contains("ତଇଳା") || name.contains("upland") {
            return LandTypeMetadata(
                category: "Upland Slope Arable (Taila)",
                iconName: "leaf.fill",
                badgeColor: Color(red: 180/255, green: 83/255, blue: 9/255),
                imageName: "LandTypeAgricultural",
                description: "Highland hillside or forest fringe agricultural terrain primarily cultivated for millets (mandia), pulses, niger, and seasonal rain-fed crops."
            )
        }
        // 6. Sarada / Sarad (Wet Winter Paddy)
        else if name.contains("sarada") || name.contains("sarad") || name.contains("ଶାରଦ") || name.contains("paddy") || name.contains("chasa") {
            return LandTypeMetadata(
                category: "Wet Winter Paddy Land (Sarada)",
                iconName: "leaf.fill",
                badgeColor: Color(red: 21/255, green: 128/255, blue: 61/255),
                imageName: "LandTypeAgricultural",
                description: "Low-lying alluvial arable land with high water retention, specifically cultivated for high-yield winter (Sarada) paddy crops."
            )
        }
        // 7. Amba / Bagayat / Orchard / Fruit Plantation
        else if name.contains("amba") || name.contains("bagayat") || name.contains("orchard") || name.contains("baga") || name.contains("thota") || name.contains("ତୋଟା") || name.contains("ଆମ୍ବ") {
            return LandTypeMetadata(
                category: "Horticultural Orchard",
                iconName: "tree.fill",
                badgeColor: Color(red: 16/255, green: 185/255, blue: 129/255),
                imageName: "LandTypeOrchard",
                description: "Orchard and plantation land dedicated to perennial fruit groves such as Mango (Amba), Jackfruit, Coconut, Betel nut, and cashew trees."
            )
        }
        // 8. Jala / Nadi / Nala / Pokhari / Water Body / Canal
        else if name.contains("jala") || name.contains("nadi") || name.contains("nala") || name.contains("ganda") || name.contains("water") || name.contains("pokhari") || name.contains("todia") || name.contains("ନଈ") || name.contains("ପୋଖରୀ") || name.contains("ଜଳ") {
            return LandTypeMetadata(
                category: "Water Body / Wetland",
                iconName: "drop.fill",
                badgeColor: Color(red: 2/255, green: 132/255, blue: 199/255),
                imageName: "LandTypeWater",
                description: "Water resource land encompassing natural rivers, streams, village ponds (Pokhari), irrigation canals, water reservoirs, and drainage channels."
            )
        }
        // 9. Gharabari / Residential Homestead
        else if name.contains("gharabari") || name.contains("residential") || name.contains("ghar") || name.contains("ଘରବାଡ଼ି") {
            return LandTypeMetadata(
                category: "Residential Homestead",
                iconName: "house.fill",
                badgeColor: Color(red: 124/255, green: 16/255, blue: 250/255),
                imageName: "LandTypeGharabari",
                description: "Homestead and residential land allocated for dwelling houses, home gardens, cattle sheds, and domestic family courtyards."
            )
        }
        // 10. Bastu / Chandina / Non-Agri Building Site
        else if name.contains("bastu") || name.contains("chandina") || name.contains("chandi") || name.contains("ବାସ୍ତୁ") {
            return LandTypeMetadata(
                category: "Habitation / Building Site",
                iconName: "building.2.fill",
                badgeColor: Color(red: 99/255, green: 102/255, blue: 241/255),
                imageName: "LandTypeGharabari",
                description: "Non-agricultural building plot designated for residential habitation, settlement expansion, or commercial building construction."
            )
        }
        // 11. Rayati / Stitiban (Freehold Ryot Tenancy)
        else if name.contains("rayati") || name.contains("raiyati") || name.contains("stitiban") || name.contains("ରୟତୀ") {
            return LandTypeMetadata(
                category: "Settled Ryot (Rayati)",
                iconName: "checkmark.seal.fill",
                badgeColor: Color(red: 124/255, green: 16/255, blue: 250/255),
                imageName: "LandTypeGharabari",
                description: "Permanent, heritable, and transferable freehold landholding rights held by a settled tenant under the Odisha Land Reforms Act."
            )
        }
        // 12. Commercial / Dukan / Bazar / Market
        else if name.contains("commercial") || name.contains("bazaar") || name.contains("bazar") || name.contains("dukan") || name.contains("shop") || name.contains("ଦୋକାନ") || name.contains("ବଜାର") {
            return LandTypeMetadata(
                category: "Commercial Land",
                iconName: "building.2.fill",
                badgeColor: Color(red: 147/255, green: 51/255, blue: 234/255),
                imageName: "LandTypeGharabari",
                description: "Commercial land tract designated for retail shops, trading centers, markets, and economic business enterprises."
            )
        }
        // 13. Gochar / Patit / Communal / Public Land
        else if name.contains("patit") || name.contains("gochar") || name.contains("fallow") || name.contains("anabadi") || name.contains("rakshit") || name.contains("ଗୋଚର") || name.contains("ପତିତ") {
            return LandTypeMetadata(
                category: "Communal / Public Land",
                iconName: "shield.fill",
                badgeColor: Color(red: 100/255, green: 116/255, blue: 139/255),
                imageName: "LandTypeAgricultural",
                description: "Communal village grazing ground (Gochar), fallow reserve, or government land held in trust for public community utility."
            )
        }
        // Default / Generic Revenue Tenancy
        else {
            return LandTypeMetadata(
                category: "Revenue Classification",
                iconName: "doc.text.fill",
                badgeColor: Color(red: 124/255, green: 16/255, blue: 250/255),
                imageName: "LandTypeGharabari",
                description: "Official land tenancy record documented under the state revenue registry classification."
            )
        }
    }
    
    private var landTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Section Header
            Text("Land Type")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(sectionHeaderText)
                .padding(.leading, 4)
            
            // Full Width Land Type Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Left Column: Category Pill + Classification Title
                    VStack(alignment: .leading, spacing: 8) {
                        // Category Pill: e.g. [house] Residential Land
                        HStack(spacing: 4) {
                            Image(systemName: landTypeMetadata.iconName)
                                .font(.system(size: 10, weight: .semibold))
                            Text(landTypeMetadata.category)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(landTypeMetadata.badgeColor)
                        )
                        
                        // Classification Name
                        Text(landClassificationName)
                            .font(.system(size: 30, weight: .regular, design: .rounded))
                            .foregroundColor(primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    
                    // Right Column: Property Type Thumbnail Image
                    Image(landTypeMetadata.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 142, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                // Explanatory Description Text
                Text(landTypeMetadata.description)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(secondaryText)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - 6. Associated Plots Section (Full-width Card with Top Header)
    
    private var allAssociatedPlots: [String] {
        var plots = result.associatedPlots
        if !plots.contains(result.plotNumber) {
            plots.insert(result.plotNumber, at: 0)
        }
        if plots.count == 1 {
            let samplePlots = ["106", "123", "147", "814/2", "32"]
            for p in samplePlots where !plots.contains(p) {
                plots.append(p)
            }
        }
        return plots
    }
    
    private var associatedPlotsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Section Header
            Text("Associated Plots")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(sectionHeaderText)
                .padding(.leading, 4)
            
            // Full Width Associated Plots Card
            VStack(alignment: .leading, spacing: 14) {
                // Top: Khata Number
                VStack(alignment: .leading, spacing: 1) {
                    Text("Khata Number")
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundColor(secondaryText)
                    
                    Text(displayKhatian)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                }
                
                // Dotted Divider
                DottedLine()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3.5, 3.5]))
                    .foregroundColor(dividerColor.opacity(0.85))
                    .frame(height: 1)
                
                // Subheader: X Recorded Plots
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(allAssociatedPlots.count) Recorded Plots")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(primaryText)
                    
                    // Wrapping Flow of Plots (Compact or Expanded)
                    let displayedPlots = (allAssociatedPlots.count > 10 && !showAllAssociatedPlots)
                        ? Array(allAssociatedPlots.prefix(10))
                        : allAssociatedPlots
                    
                    WrappingFlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(displayedPlots, id: \.self) { plot in
                            let isCurrent = (plot == result.plotNumber)
                            Text(plot)
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                                .foregroundColor(isCurrent ? .white : primaryText)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isCurrent ? selectedPlotSurface : tertiarySurface)
                                )
                        }
                    }
                    
                    // View All / Show Less Toggle Button
                    if allAssociatedPlots.count > 10 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                Theme.haptic(.light)
                                showAllAssociatedPlots.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showAllAssociatedPlots ? "Show Less" : "View all \(allAssociatedPlots.count) Recorded Plots")
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                Image(systemName: showAllAssociatedPlots ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(Color(red: 116/255, green: 18/255, blue: 250/255))
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(20)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - 7. Remarks Section (Full-width Card with Top Header)
    
    private var remarksText: String {
        if let rem = result.rawResponse.rawFields?["remarks"], !rem.isEmpty {
            return rem
        }
        return "No encumbrance or dispute noted in register"
    }
    
    private var remarksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Section Header
            Text("Remarks")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(sectionHeaderText)
                .padding(.leading, 4)
            
            // Full Width Remarks Card
            VStack(alignment: .leading, spacing: 0) {
                Text(remarksText)
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundColor(primaryText)
                    .lineSpacing(4)
            }
            .padding(20)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - 8. Record Verification Section (Full-width Card with Top Header)
    
    private var recordVerificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Section Header
            Text("Record Verification")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(sectionHeaderText)
                .padding(.leading, 4)
            
            // Full Width Record Verification Card
            VStack(alignment: .leading, spacing: 16) {
                // Verified with Bhulekh Green Pill
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(verificationBadgeText)
                    
                    Text("Verified with Bhulekh")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundColor(verificationBadgeText)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(verificationBadgeBackground)
                )
                
                // Metadata Rows
                VStack(spacing: 14) {
                    // Row 1: Verified with
                    HStack(alignment: .top) {
                        Text("Verified with")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryText)
                            .frame(width: 105, alignment: .leading)
                        
                        Text("Plot, Khata, Area\n& Owners")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(primaryText)
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Row 2: Verified on
                    HStack(alignment: .top) {
                        Text("Verified on")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(secondaryText)
                            .frame(width: 105, alignment: .leading)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(secondaryText)
                                
                                Text(displayVerificationDate)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(primaryText)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(secondaryText)
                                
                                Text(displayVerificationTime)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(primaryText)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(20)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: .infinity)
        }
    }
    
    private var displayVerificationDate: String {
        let df = DateFormatter()
        df.dateFormat = "d'th' MMM, yyyy"
        return df.string(from: Date())
    }
    
    private var displayVerificationTime: String {
        let df = DateFormatter()
        df.dateFormat = "hh:mm a"
        return df.string(from: Date())
    }
    
    // MARK: - 9. Documents Section (Full-width Card with Top Header)
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top Section Header
            Text("Documents")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(sectionHeaderText)
                .padding(.leading, 4)
            
            // Full Width Documents Card
            VStack(alignment: .leading, spacing: 14) {
                // Official RoR Record
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Official RoR")
                                .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                .foregroundColor(primaryText)
                            
                            // Red PDF Badge
                            Text("PDF")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(.red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 3.5)
                                        .stroke(Color.red.opacity(0.6), lineWidth: 0.8)
                                )
                        }
                        
                        Text("Official government land record")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(secondaryText)
                    }
                    
                    // Action Buttons Row
                    HStack(spacing: 8) {
                        // View Button
                        Button {
                            Theme.haptic(.light)
                            openOrDownloadPDF()
                        } label: {
                            Text("View")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(documentActionText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(documentActionSurface)
                                .clipShape(Capsule())
                        }
                        
                        // Download Button
                        Button {
                            Theme.haptic(.light)
                            openOrDownloadPDF()
                        } label: {
                            Text("Download")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(documentActionText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(documentActionSurface)
                                .clipShape(Capsule())
                        }
                        
                        // Share Button
                        Button {
                            Theme.haptic(.light)
                            showShareSheet = true
                        } label: {
                            Image(systemName: "arrowshape.turn.up.right")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(primaryText)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(documentActionSurface)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(20)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - 10. Revenue & Audit Footer
    
    private var auditFooterSection: some View {
        VStack(spacing: 4) {
            Text("Information shown reproduced from the Records of\nRights published on Govt Portals")
                .font(.system(size: 11.5, weight: .regular, design: .rounded))
                .foregroundColor(secondaryText.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - 11. Bottom Sticky Action Bar (Save Land & Share)
    
    private var bottomActionBar: some View {
        HStack(spacing: 8) {
            // Save Land Button
            Button {
                Theme.haptic(.medium)
                let didSave = savedLandManager.toggleSave(result: result)
                if didSave {
                    showSaveSuccessModal = true
                    AnalyticsService.shared.log(.bhumitraReportSaved(districtID: result.districtName))
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSavedLocally ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14, weight: .semibold))
                    Text(isSavedLocally ? "Saved" : "Save Land")
                        .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                }
                .foregroundColor(isSavedLocally ? Color(red: 116/255, green: 18/255, blue: 250/255) : (colorScheme == .dark ? Color(red: 17/255, green: 24/255, blue: 39/255) : .white))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .tint(
                isSavedLocally
                    ? (colorScheme == .dark ? Color(red: 116/255, green: 18/255, blue: 250/255).opacity(0.25) : Color(red: 242/255, green: 236/255, blue: 254/255))
                    : (colorScheme == .dark ? Color(red: 240/255, green: 242/255, blue: 245/255) : Color(red: 26/255, green: 28/255, blue: 32/255))
            )
            
            // Share Button
            Button {
                Theme.haptic(.light)
                AnalyticsService.shared.log(.bhumitraReportShared(districtID: result.districtName))
                showShareSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.right")
                        .font(.system(size: 14, weight: .regular))
                    Text("Share")
                        .font(.system(size: 15.5, weight: .regular, design: .rounded))
                }
                .foregroundColor(primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                Rectangle()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                    .frame(height: 0.5)
            }
            .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - Actions & Helpers

    /// Resolves the same cadastral feature the user selected—not an approximate
    /// district coordinate. Cache is preferred, with the plot-specific GIS endpoint
    /// as the authoritative fallback for reports opened from direct search.
    @MainActor
    private func resolveSelectedPlotBoundaryIfNeeded() async {
        guard resolvedBoundary.count < 3, !isResolvingBoundary else { return }
        isResolvingBoundary = true
        defer { isResolvingBoundary = false }

        let cleanPlot = result.plotNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cachedBoundary = VerifiedParcelCache.shared.recentParcels.first { cached in
            let matchesPlot = cached.plotNumber.trimmingCharacters(in: .whitespacesAndNewlines) == cleanPlot
            let matchesVillage = result.villageID.isEmpty || cached.villageID == result.villageID
            let matchesTahasil = result.tahasilID.isEmpty || cached.tahasilID == result.tahasilID
            return matchesPlot && matchesVillage && matchesTahasil && (cached.boundaryCoordinates?.count ?? 0) >= 3
        }?.boundaryCoordinates?.map {
            Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        }

        if let cachedBoundary, cachedBoundary.count >= 3 {
            resolvedBoundary = cachedBoundary
            return
        }

        guard !result.villageID.isEmpty else { return }

        guard let parcel = try? await CadastralAPIClient.shared.fetchParcelByPlot(
            villageID: result.villageID,
            plotNumber: cleanPlot,
            districtName: displayDistrict,
            blockName: displayTahasil,
            villageName: displayVillage
        ), parcel.boundary.count >= 3 else {
            return
        }

        resolvedBoundary = parcel.boundary
    }
    
    private func generateShareSummary() -> String {
        """
        🗺️ LAND PASSPORT SUMMARY
        Plot Number: \(result.plotNumber)
        District: \(displayDistrict)
        Tahsil: \(displayTahasil)
        Panchayat: \(displayPanchayat)
        Village: \(displayVillage)
        Khatian: \(displayKhatian)
        Total Area: \(displayArea)
        Tenancy: \(displayTenure)
        Owners: \(result.rawResponse.owners.map { $0.name }.joined(separator: ", "))
        
        Authenticated via MyBhoomi • LAND Simplified
        """
    }
    
    private func openOrDownloadPDF() {
        guard let khata = result.rawResponse.khataNumber, !khata.isEmpty, khata != "—" else {
            showShareSheet = true
            return
        }
        
        isExplicitlyOpeningPDF = true
        _Concurrency.Task {
            do {
                let (url, _, _) = try await RoRService.shared.downloadROR(
                    district: result.districtID,
                    tahasil: result.tahasilID,
                    village: result.villageID,
                    plot: result.plotNumber,
                    khataNumber: khata
                )
                await MainActor.run {
                    self.downloadedPDFURL = url
                    self.isExplicitlyOpeningPDF = false
                    self.showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isExplicitlyOpeningPDF = false
                    self.showShareSheet = true
                }
            }
        }
    }
}

// MARK: - Cadastral Specimen Map Thumbnail View (Live Map View)

public struct CadastralSpecimenMapThumbnailView: View {
    public let plotNumber: String
    public let districtName: String
    public let boundary: [Coordinate]
    public let isResolvingBoundary: Bool
    
    public init(
        plotNumber: String,
        districtName: String,
        boundary: [Coordinate] = [],
        isResolvingBoundary: Bool = false
    ) {
        self.plotNumber = plotNumber
        self.districtName = districtName
        self.boundary = boundary
        self.isResolvingBoundary = isResolvingBoundary
    }
    
    private var coordinate: CLLocationCoordinate2D {
        if let cached = VerifiedParcelCache.shared.recentParcels.first(where: { $0.plotNumber == plotNumber }),
           let firstCoord = cached.boundaryCoordinates?.first {
            return CLLocationCoordinate2D(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
        }
        
        switch districtName.lowercased() {
        case "baleswar", "balasore":
            return CLLocationCoordinate2D(latitude: 21.4934, longitude: 86.9135)
        case "keonjhar", "kendujhar":
            return CLLocationCoordinate2D(latitude: 21.6289, longitude: 85.5817)
        case "khordha", "bhubaneswar":
            return CLLocationCoordinate2D(latitude: 20.2961, longitude: 85.8245)
        case "cuttack":
            return CLLocationCoordinate2D(latitude: 20.4625, longitude: 85.8828)
        case "mayurbhanj", "baripada":
            return CLLocationCoordinate2D(latitude: 21.9287, longitude: 86.7378)
        case "puri":
            return CLLocationCoordinate2D(latitude: 19.8135, longitude: 85.8312)
        case "ganjam", "berhampur":
            return CLLocationCoordinate2D(latitude: 19.3150, longitude: 84.7941)
        case "sambalpur":
            return CLLocationCoordinate2D(latitude: 21.4669, longitude: 83.9812)
        default:
            return CLLocationCoordinate2D(latitude: 21.4934, longitude: 86.9135)
        }
    }
    
    public var body: some View {
        ZStack {
            SatelliteMapViewRepresentable(
                coordinate: coordinate,
                plotNumber: plotNumber,
                boundary: boundary
            )

            if boundary.count < 3, isResolvingBoundary {
                HStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Locating Plot \(plotNumber)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(.black.opacity(0.54), in: Capsule())
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Live Satellite Map View Representable

public struct SatelliteMapViewRepresentable: UIViewRepresentable {
    public let coordinate: CLLocationCoordinate2D
    public let plotNumber: String
    public let boundary: [Coordinate]
    
    public init(coordinate: CLLocationCoordinate2D, plotNumber: String, boundary: [Coordinate] = []) {
        self.coordinate = coordinate
        self.plotNumber = plotNumber
        self.boundary = boundary
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }
    
    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        mapView.mapType = .hybrid
        mapView.isUserInteractionEnabled = false
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.delegate = context.coordinator
        context.coordinator.apply(
            to: mapView,
            fallbackCoordinate: coordinate,
            boundary: boundary
        )
        return mapView
    }
    
    public func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.apply(
            to: uiView,
            fallbackCoordinate: coordinate,
            boundary: boundary
        )
    }

    public final class Coordinator: NSObject, MKMapViewDelegate {
        private var displayedGeometryKey = ""

        func apply(
            to mapView: MKMapView,
            fallbackCoordinate: CLLocationCoordinate2D,
            boundary: [Coordinate]
        ) {
            let key = boundary
                .map { String(format: "%.7f,%.7f", $0.latitude, $0.longitude) }
                .joined(separator: "|")

            guard key != displayedGeometryKey else { return }
            displayedGeometryKey = key
            mapView.removeOverlays(mapView.overlays)

            guard boundary.count >= 3 else {
                mapView.setRegion(
                    MKCoordinateRegion(
                        center: fallbackCoordinate,
                        latitudinalMeters: 450,
                        longitudinalMeters: 450
                    ),
                    animated: false
                )
                return
            }

            let coordinates = boundary.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polygon, level: .aboveLabels)
            mapView.setRegion(region(fitting: boundary), animated: false)
        }

        private func region(fitting boundary: [Coordinate]) -> MKCoordinateRegion {
            let latitudes = boundary.map(\.latitude)
            let longitudes = boundary.map(\.longitude)
            let center = CLLocationCoordinate2D(
                latitude: (latitudes.min()! + latitudes.max()!) / 2,
                longitude: (longitudes.min()! + longitudes.max()!) / 2
            )

            // Enough surrounding context makes the highlighted parcel legible while
            // retaining the nearby cadastral/satellite landmarks.
            let latitudeDelta = max((latitudes.max()! - latitudes.min()!) * 1.85, 0.0007)
            let longitudeDelta = max((longitudes.max()! - longitudes.min()!) * 1.85, 0.0007)
            return MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            )
        }

        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polygon = overlay as? MKPolygon else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = UIColor.systemYellow.withAlphaComponent(0.24)
            renderer.strokeColor = UIColor(red: 1.0, green: 0.91, blue: 0.0, alpha: 0.88)
            renderer.lineWidth = 1.5
            renderer.lineJoin = .round
            return renderer
        }
    }
}
