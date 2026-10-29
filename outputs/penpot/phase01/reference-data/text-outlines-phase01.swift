// Convert synthetic reference text to native macOS glyph outlines. No font files are copied.
import Foundation
import AppKit
import CoreText

func n(_ x: Any?, _ fallback: Double = 0) -> Double { (x as? NSNumber)?.doubleValue ?? Double(x as? String ?? "") ?? fallback }
func number(_ x: Double) -> String { let s=String(format:"%.5f",x); return s.replacingOccurrences(of:"0+$",with:"",options:.regularExpression).replacingOccurrences(of:"\\.$",with:"",options:.regularExpression) }
func rectDict(_ r: CGRect) -> [String:Double] { ["x":r.minX,"y":r.minY,"width":r.width,"height":r.height] }
func escaped(_ s:String)->String { s.replacingOccurrences(of:"&",with:"&amp;").replacingOccurrences(of:"<",with:"&lt;").replacingOccurrences(of:">",with:"&gt;").replacingOccurrences(of:"\"",with:"&quot;") }
func cssWeight(_ w: Double)->NSFont.Weight {
 let stops:[(Double,Double)]=[(100,-0.8),(200,-0.6),(300,-0.4),(400,0),(500,0.23),(600,0.3),(700,0.4),(800,0.56),(900,0.62)]
 if w<=100{return NSFont.Weight(rawValue:-0.8)}
 for i in 1..<stops.count where w<=stops[i].0 {let a=stops[i-1],b=stops[i];return NSFont.Weight(rawValue:a.1+(b.1-a.1)*(w-a.0)/(b.0-a.0))}
 return NSFont.Weight(rawValue:0.62)
}
func makeFont(_ style:[String:Any]) -> CTFont {
 let size=n(style["fontSize"].map{String(describing:$0).replacingOccurrences(of:"px",with:"")},15)
 let family=style["fontFamily"] as? String ?? "Geeza Pro"
 let weight=n(style["fontWeight"],400)
 if family == "-apple-system, sans-serif" {
  let raw = weight >= 600 ? "Helvetica-Bold" : "Helvetica"
  let base=CTFontCreateWithName(raw as CFString,size,nil)
  let cascade=CTFontDescriptorCreateWithAttributes([kCTFontCascadeListAttribute:[CTFontDescriptorCreateWithNameAndSize((weight >= 600 ? "GeezaPro-Bold" : "GeezaPro") as CFString,size)]] as CFDictionary)
  return CTFontCreateCopyWithAttributes(base,size,nil,cascade)
 }
 if family.lowercased().contains("system") || family.lowercased().contains("apple") {
  let mono=(style["fontVariantNumeric"] as? String ?? "").contains("tabular")
  let base = (mono ? NSFont.monospacedDigitSystemFont(ofSize:size,weight:cssWeight(weight)):NSFont.systemFont(ofSize:size,weight:cssWeight(weight))) as CTFont
  let variation = CTFontDescriptorCreateWithAttributes([kCTFontVariationAttribute:[2003265652:weight]] as CFDictionary)
  return CTFontCreateCopyWithAttributes(base,size,nil,variation)
 }
 if family.lowercased() == "monospace" { return CTFontCreateWithName("Menlo" as CFString,size,nil) }
 let raw=family.split(separator:",").first.map(String.init)?.replacingOccurrences(of:"\"",with:"").trimmingCharacters(in:.whitespaces) ?? "Geeza Pro"
 var font=CTFontCreateWithName(raw as CFString,size,nil)
 if weight>=600,let bold=CTFontCreateCopyWithSymbolicTraits(font,size,nil,.boldTrait,.boldTrait) {font=bold}
 if (style["fontStyle"] as? String)=="italic",let italic=CTFontCreateCopyWithSymbolicTraits(font,size,nil,.italicTrait,.italicTrait) {font=italic}
 let cascadeName = weight >= 600 ? "Tahoma-Bold" : "Tahoma"
 let cascade = CTFontDescriptorCreateWithAttributes([kCTFontCascadeListAttribute:[CTFontDescriptorCreateWithNameAndSize(cascadeName as CFString,size)]] as CFDictionary)
 return CTFontCreateCopyWithAttributes(font,size,nil,cascade)
}
func pathData(_ path:CGPath, x:Double,y:Double,scaleX:Double=1) ->String {
 var out=""
 func pt(_ p:CGPoint)->String {number(x+p.x*scaleX)+" "+number(y-p.y)}
 path.applyWithBlock{ ptr in
  let e=ptr.pointee
  switch e.type {
  case .moveToPoint:out+="M"+pt(e.points[0])
  case .addLineToPoint:out+="L"+pt(e.points[0])
  case .addQuadCurveToPoint:out+="Q"+pt(e.points[0])+" "+pt(e.points[1])
  case .addCurveToPoint:out+="C"+pt(e.points[0])+" "+pt(e.points[1])+" "+pt(e.points[2])
  case .closeSubpath:out+="Z"
  @unknown default:break
  }
 }
 return out
}
func baselineKey(_ style:[String:Any], _ bounds:[String:Any]) -> String {
 ["fontFamily","fontSize","fontWeight","fontStyle","fontVariantNumeric","letterSpacing"].map {String(describing:style[$0] ?? "")}.joined(separator:"|") + "|" + number(n(bounds["height"]))
}
func convert(_ input:[[String:Any]]) -> ([String:Any]) {
 var validatedAscents=[String:[Double]]()
 for run in input {
  let style=run["style"] as? [String:Any] ?? [:]
  for line in run["lines"] as? [[String:Any]] ?? [] {
   if line["baselineReliable"] as? Bool == true, let value=line["domBaseline"] as? NSNumber, let b=line["bounds"] as? [String:Any], value.doubleValue >= n(b["y"]), value.doubleValue <= n(b["y"])+n(b["height"]) {
    validatedAscents[baselineKey(style,b),default:[]].append(value.doubleValue-n(b["y"]))
   }
  }
 }
 var output=[[String:Any]]();var fontCounts=[String:Int]();var widthErrors=[Double]();var baselineWarnings=[String]()
 for run in input {
  let id=run["id"] as? String ?? "unknown",sourceText=run["text"] as? String ?? run["characters"] as? String ?? ""
  let style=run["style"] as? [String:Any] ?? [:],font=makeFont(style)
  let para=NSMutableParagraphStyle();para.baseWritingDirection=(style["direction"] as? String)=="rtl" ? .rightToLeft:.leftToRight
  let attrs:[NSAttributedString.Key:Any]=[NSAttributedString.Key(kCTFontAttributeName as String):font,.paragraphStyle:para]
  let spacing=style["letterSpacing"] as? String ?? "normal"
  let spacingValue = Double(spacing.replacingOccurrences(of:"px",with:"")) ?? 0
  let lines=run["lines"] as? [[String:Any]] ?? [["text":sourceText,"bounds":run["bounds"] ?? [:]]]
  var convertedLines=[[String:Any]](),combined=""
  for item in lines {
   var text=item["text"] as? String ?? sourceText
   let b=item["bounds"] as? [String:Any] ?? [:]
   if text.isEmpty {continue}
   let bounds=CGRect(x:n(b["x"]),y:n(b["y"]),width:n(b["width"]),height:n(b["height"]))
   let metrics=item["metrics"] as? [String:Any] ?? run["metrics"] as? [String:Any] ?? [:]
   let attributed = NSMutableAttributedString(string:text,attributes:attrs)
   if spacingValue != 0 {
    // Chromium suppresses tracking inside Arabic joining sequences. Keep the
    // joining font untouched and apply CSS tracking only to spacing/Latin runs.
    let ns = text as NSString
    for i in 0..<ns.length {
     let code = ns.character(at:i)
     let arabic = (0x0600...0x08ff).contains(Int(code)) || (0xfb50...0xfdff).contains(Int(code)) || (0xfe70...0xfeff).contains(Int(code))
     if !arabic {attributed.addAttribute(NSAttributedString.Key(kCTKernAttributeName as String),value:spacingValue,range:NSRange(location:i,length:1))}
    }
   }
   var line=CTLineCreateWithAttributedString(attributed)
   if lines.count == 1 && sourceText != text && spacingValue == 0 && sourceText.trimmingCharacters(in:.whitespacesAndNewlines) == text {
    let untrimmed = CTLineCreateWithAttributedString(NSAttributedString(string:sourceText,attributes:attrs))
    if abs(CTLineGetTypographicBounds(untrimmed,nil,nil,nil)-bounds.width) < abs(CTLineGetTypographicBounds(line,nil,nil,nil)-bounds.width) {
     text = sourceText; line = untrimmed
    }
   }
   var ascent:CGFloat=0,descent:CGFloat=0,leading:CGFloat=0
   let advance=CTLineGetTypographicBounds(line,&ascent,&descent,&leading)
   let canvasFont=run["canvasFont"] as? String ?? ""
   let validCanvas = !canvasFont.hasPrefix("10px sans-serif") || (style["fontSize"] as? String)=="10px"
   let canvasAscent=n(metrics["fontBoundingBoxAscent"],ascent)
   // Preserve the requested canvas-derived baseline and expose all metrics for the parent's overlay comparison.
   // Canvas uses integer font bounding metrics; DOM layout can retain fractional baselines.
   let canvasBaseline = bounds.minY + (validCanvas ? canvasAscent : max(0,bounds.height-descent))
   // A validated DOM baseline is authoritative when provided by the exporter.
   let rawMeasured = item["baselineReliable"] as? Bool == true ? (item["domBaseline"] as? NSNumber)?.doubleValue : nil
   let measuredBaseline = rawMeasured.flatMap { $0 >= bounds.minY && $0 <= bounds.maxY ? $0 : nil }
   let matches=validatedAscents[baselineKey(style,b)] ?? []
   // Wrapped end markers can move to a later line without moving the text.
   // Use the dominant validated ascent rather than such baseline outliers.
   let clusters = Dictionary(grouping: matches, by: {number(($0*64).rounded()/64)})
   let dominant = clusters.values.max(by: {$0.count < $1.count}) ?? []
   let matchingAscent = dominant.count >= 2 ? dominant.sorted()[dominant.count/2] : nil
   let derivedBaseline = matchingAscent.map{bounds.minY+$0}
   let nativeControlBaseline = run["owner"] != nil ? bounds.minY+ascent : nil
   let baseline = nativeControlBaseline ?? measuredBaseline ?? derivedBaseline ?? canvasBaseline
   let baselineMethod = nativeControlBaseline != nil ? "native-control range-top+CoreText-ascent; UA shadow marker rejected after source ink-location check" : measuredBaseline != nil ? "validated DOM baseline marker" : (derivedBaseline != nil ? "validated matching-style DOM ascent" : (validCanvas ? "range-top+canvas-fontBoundingBoxAscent" : "range-bottom-CoreText-descent (canvas-font fallback invalid)"))
   if !validCanvas {baselineWarnings.append(id)}
   let targetWidth=bounds.width,err=abs(advance-targetWidth);widthErrors.append(err)
   var glyphCount=0,paths=[String](),fonts=[String]()
   for value in CTLineGetGlyphRuns(line) as! [CTRun] {
    let count=CTRunGetGlyphCount(value);if count==0{continue}
    let a=CTRunGetAttributes(value) as NSDictionary
    let actual=a[kCTFontAttributeName] as! CTFont
    let fontName=CTFontCopyPostScriptName(actual) as String
    fontCounts[fontName,default:0]+=count;if !fonts.contains(fontName){fonts.append(fontName)}
    var glyphs=[CGGlyph](repeating:0,count:count),positions=[CGPoint](repeating:.zero,count:count)
    CTRunGetGlyphs(value,CFRange(location:0,length:0),&glyphs);CTRunGetPositions(value,CFRange(location:0,length:0),&positions)
    for i in 0..<count {
     if let path=CTFontCreatePathForGlyph(actual,glyphs[i],nil) {
      let d=pathData(path,x:bounds.minX+positions[i].x,y:baseline-positions[i].y)
      paths.append(d);glyphCount+=1
     }
    }
   }
   let d=paths.joined(),svg="<g id=\""+escaped(id)+"\" data-text=\""+escaped(text)+"\"><path d=\""+d+"\"/></g>"
   combined+=svg
   convertedLines.append(["text":text,"bounds":b,"baseline":baseline,"baselineMethod":baselineMethod,"canvasBaseline":canvasBaseline,"coreTextBaseline":bounds.minY+ascent,"centeredCoreTextBaseline":bounds.minY+(bounds.height-ascent-descent)/2+ascent,"canvasAscent":canvasAscent,"coreTextAscent":ascent,"coreTextDescent":descent,"coreTextLeading":leading,"coreTextAdvance":advance,"sourceAdvance":targetWidth,"advanceError":err,"scaleX":1,"fonts":fonts,"glyphCount":glyphCount,"path":d,"svg":svg])
  }
  output.append(["id":id,"text":sourceText,"bounds":run["bounds"] ?? [:],"style":style,"lines":convertedLines,"svg":combined])
 }
 let sorted=widthErrors.sorted()
 return ["runs":output,"fontSummary":fontCounts,"runCount":output.count,"lineCount":widthErrors.count,"maximumAdvanceError":sorted.last ?? 0,"medianAdvanceError":sorted.isEmpty ? 0:sorted[sorted.count/2],"invalidCanvasMetricRunIds":baselineWarnings,"notes":["Native CoreText/AppKit glyph paths; no font files copied or uploaded.","All coordinates are absolute in the recorded source viewport.","Paths inherit fill from the parent SVG wrapper.","No width scaling applied; compare exports before claiming pixel identity.","Explicit CSS Tahoma cascade and variable SFNS weight preserve browser fallback and weight650.","Arabic joining runs suppress letter spacing; spacing and Latin runs retain it.","Validated DOM baselines are authoritative; exact-style measured ascent is used for equivalent runs whose marker changed only horizontal whitespace. Canvas and CoreText alternatives remain available for comparison."]]
}
let base=CommandLine.arguments.count>1 ? CommandLine.arguments[1]:"outputs/penpot/phase00/reference-data"
let directory=URL(fileURLWithPath:base,isDirectory:true)
var controlsByScreen=[String:[[String:Any]]]()
let controls=directory.appendingPathComponent("control-runs.json")
if let data=try? Data(contentsOf:controls),let entries=(try? JSONSerialization.jsonObject(with:data)) as? [[String:Any]] {
 for entry in entries {controlsByScreen[entry["id"] as? String ?? ""]=entry["runs"] as? [[String:Any]] ?? []}
}
let screenNames = CommandLine.arguments.count>2 ? CommandLine.arguments[2].split(separator:",").map(String.init) : ["desktop-sales","desktop-navigation","desktop-invoice-new","phone-invoice-new","phone-sales","design-system","medium-sales","wide-sales"]
for name in screenNames {
 let data=try Data(contentsOf:directory.appendingPathComponent(name+".json")),j=try JSONSerialization.jsonObject(with:data) as! [String:Any]
 let texts=j["texts"] as? [[String:Any]] ?? []
 let result=convert(texts+(controlsByScreen[name] ?? []))
 let out=directory.appendingPathComponent(name+"-text-outlines.json")
 try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:out)
 print(name, "runs", result["runCount"]!, "max advance error",result["maximumAdvanceError"]!,"median",result["medianAdvanceError"]!,"canvas fallbacks",(result["invalidCanvasMetricRunIds"] as! [String]).count)
}
