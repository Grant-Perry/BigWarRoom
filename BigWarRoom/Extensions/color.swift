//
   //  Color+Ext.swift
   //  howFar Watch App
   //
   //  Created by Grant Perry on 4/3/23.
   //

import SwiftUI

extension Color {

   init(rgb: Int...) {
	  if rgb.count == 3 {
		 self.init(red: Double(rgb[0]) / 255.0, green: Double(rgb[1]) / 255.0, blue: Double(rgb[2]) / 255.0)
	  } else {
		 self.init(red: 1.0, green: 0.5, blue: 1.0)
	  }
   }

   static let gpPastelMint = Color(#colorLiteral(red: 0.816, green: 1, blue: 0.647, alpha: 1)) 
   static let gpGreen = Color(#colorLiteral(red: 0.3911147745, green: 0.8800172018, blue: 0.2343971767, alpha: 1))
   static let gpMinty = Color(#colorLiteral(red: 0.5960784314, green: 1, blue: 0.5960784314, alpha: 1))
   static let gpFlatGreen = Color(#colorLiteral(red: 0.03852885208, green: 0.6235294342, blue: 0.3622174664, alpha: 1))

   static let gpArmyGreen = Color(#colorLiteral(red: 0.4392156863, green: 0.4352941176, blue: 0.1803921569, alpha: 1))
   static let gpOrange = Color(#colorLiteral(red: 1, green: 0.6470588235, blue: 0, alpha: 1))
   static let gpPink = Color(#colorLiteral(red: 1, green: 0.4117647059, blue: 0.7058823529, alpha: 1))
   static let gpPurple = Color(#colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1))
   static let gpDkPurple = Color(#colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 1))
   static let gpRed = Color(#colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1))

	  /// App-wide white for strokes and accents
   static let gpWhite = Color.white

   static let gpRedPitch = Color(#colorLiteral(red: 0.9254902005, green: 0.2352941185, blue: 0.1019607857, alpha: 1))
   static let gpBluePitch = Color(#colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1))

   static let gpRedPink = Color(#colorLiteral(red: 1, green: 0.1857388616, blue: 0.3251032516, alpha: 1))
   static let gpYellowD = Color(#colorLiteral(red: 0.7254902124, green: 0.4784313738, blue: 0.09803921729, alpha: 1))
   static let gpYellow = Color(#colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1))
   static let gpDeltaPurple = Color(#colorLiteral(red: 0.5450980392, green: 0.1019607843, blue: 0.2901960784, alpha: 1))
   static let gpMaroon = Color(#colorLiteral(red: 0.4392156863, green: 0.1803921569, blue: 0.3137254902, alpha: 1))
   static let gpBlueDark = Color(#colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1))
   static let gpBlueDarkL = Color(#colorLiteral(red: 0.08346207272, green: 0.1920862778, blue: 0.2470588237, alpha: 1))
   static let gpBlueLight = Color(#colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1))
   static let gpBlue = Color(#colorLiteral(red: 0.4620226622, green: 0.8382837176, blue: 1, alpha: 1))
   static let gpLtBlue = Color(#colorLiteral(red: 0.7, green: 0.9, blue: 1, alpha: 1))

   static let gpDark1 = Color(#colorLiteral(red: 0.1378855407, green: 0.1486340761, blue: 0.1635932028, alpha: 1))
   static let gpDark2 = Color(#colorLiteral(red: 0.1298420429, green: 0.1298461258, blue: 0.1298439503, alpha: 1))

   static let gpPostTop = Color(#colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1))
   static let gpPostBot = Color(#colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1))

   static let gpCurrentTop = Color(#colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1))
   static let gpCurrentBot = Color(#colorLiteral(red: 0.3128006691, green: 0.4008095726, blue: 0.6235075593, alpha: 1))

   static let gpScheduledTop = Color(#colorLiteral(red: 0.3156160096, green: 0.6235294342, blue: 0.5034397076, alpha: 1))
   static let gpScheduledBot = Color(#colorLiteral(red: 0.03852885208, green: 0.6235294342, blue: 0.3622174664, alpha: 1))

   static let gpFinalTop = Color(#colorLiteral(red: 0.4196078431, green: 0.2901960784, blue: 0.4745098039, alpha: 1))
   static let gpLivePlayHead = Color(#colorLiteral(red: 0.4196078431, green: 0.2901960784, blue: 0.4745098039, alpha: 1))

   static let gpFinalBot = Color(#colorLiteral(red: 0.768627451, green: 0.6078431373, blue: 0.8588235294, alpha: 1))

   static let awayTeamColor = Color(#colorLiteral(red: 0.0, green: 0.404, blue: 0.439, alpha: 1)) // #006774
   static let homeTeamColor = Color(#colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1))

	  // MLB Team Colors

   static let nyyDark = Color(#colorLiteral(red: 0.047, green: 0.137, blue: 0.251, alpha: 1)) // #0C2340
   static let rockiesPrimary = Color(#colorLiteral(red: 0.345, green: 0.267, blue: 0.541, alpha: 1)) // #58448A
   static let padresDark = Color(#colorLiteral(red: 0.204, green: 0.157, blue: 0.086, alpha: 1)) // #342814
   static let marinersPrimary = Color(#colorLiteral(red: 0.0, green: 0.404, blue: 0.439, alpha: 1)) // #006774
   static let marinersDark = Color(#colorLiteral(red: 0.0, green: 0.176, blue: 0.192, alpha: 1)) // #002D31
   static let nyyPrimary = Color(#colorLiteral(red: 0.0, green: 0.188, blue: 0.529, alpha: 1)) // #003087

   static let marlinsPrimary = Color(#colorLiteral(red: 0.0, green: 0.729, blue: 0.831, alpha: 1)) // #00BAD4
   static let marlinsDark = Color(#colorLiteral(red: 0.0, green: 0.263, blue: 0.306, alpha: 1)) // #00434E


	  /// Calculate luminance using WCAG formula
   func luminance() -> Double {
	  let uiColor = UIColor(self)
	  var red: CGFloat = 0
	  var green: CGFloat = 0
	  var blue: CGFloat = 0

	  uiColor.getRed(&red, green: &green, blue: &blue, alpha: nil)

		 // Apply gamma correction according to WCAG
	  func adjustComponent(_ component: CGFloat) -> CGFloat {
		 return component <= 0.03928 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
	  }

	  let adjRed = adjustComponent(red)
	  let adjGreen = adjustComponent(green)
	  let adjBlue = adjustComponent(blue)

		 // WCAG luminance formula
	  return 0.2126 * Double(adjRed) + 0.7152 * Double(adjGreen) + 0.0722 * Double(adjBlue)
   }

	  /// Determine if color is light based on luminance
   func isLight() -> Bool {
	  return luminance() > 0.5
   }

	  /// Return appropriate contrasting text color (black or white)
   func adaptedTextColor() -> Color {
	  return isLight() ? Color.black : Color.white
   }

	  /// Calculate WCAG contrast ratio against another color
   func contrastRatio(against color: Color) -> Double {
	  let luminance1 = self.luminance()
	  let luminance2 = color.luminance()
	  let lighter = max(luminance1, luminance2)
	  let darker = min(luminance1, luminance2)
	  return (lighter + 0.05) / (darker + 0.05)
   }

   func interpolated(with color: Color, by factor: Double) -> Color {
      let factor = max(0, min(1, factor)) // Clamp factor between 0 and 1

         // Convert SwiftUI Colors to UIColors for easier interpolation
      let uiColor1 = UIColor(self)
      let uiColor2 = UIColor(color)

      var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
      var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

      uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
      uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

      let r = r1 + (r2 - r1) * factor
      let g = g1 + (g2 - g1) * factor
      let b = b1 + (b2 - b1) * factor
      let a = a1 + (a2 - a1) * factor

      return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
   }
   
   // 🔥 DRY: Moved from DraftWarRoomApp.swift
   /// Get RGB components of color for interpolation and manipulation
   var components: (red: Double, green: Double, blue: Double, alpha: Double) {
       let uiColor = UIColor(self)
       var red: CGFloat = 0
       var green: CGFloat = 0
       var blue: CGFloat = 0
       var alpha: CGFloat = 0
       uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
       return (Double(red), Double(green), Double(blue), Double(alpha))
   }
}
