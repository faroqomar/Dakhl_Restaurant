import Foundation
import AppKit
import CoreText
let fonts=["Menlo","Courier",".SFNS-Regular",".SFNS-Bold"]
for f in fonts {let font=CTFontCreateWithName(f as CFString,12,nil);let a=NSAttributedString(string:"#f6f7f2",attributes:[NSAttributedString.Key(kCTFontAttributeName as String):font]);print(f,CTLineGetTypographicBounds(CTLineCreateWithAttributedString(a),nil,nil,nil))}
