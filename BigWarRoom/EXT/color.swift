   //
   //  Color+Ext.swift
   //  howFar Watch App
   //
   //  Created by Grant Perry on 4/3/23.
   //

import SwiftUI

extension Color {

   static let gpPastelMint = Color(#colorLiteral(red: 0.816, green: 1, blue: 0.647, alpha: 1)) // Pastel mint
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
   static let gpYellowD = Color(#colorLiteral(red: 0.5741485357, green: 0.5741624236, blue: 0.574154973, alpha: 1))
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

   static let angelsPrimary = Color(#colorLiteral(red: 0.698, green: 0.0, blue: 0.106, alpha: 1)) // #B71234
   static let angelsDark = Color(#colorLiteral(red: 0.286, green: 0.035, blue: 0.051, alpha: 1)) // #49090D

   static let astrosPrimary = Color(#colorLiteral(red: 0.992, green: 0.365, blue: 0.0, alpha: 1)) // #FD5000
   static let astrosDark = Color(#colorLiteral(red: 0.204, green: 0.067, blue: 0.0, alpha: 1)) // #340F00

   static let athleticsPrimary = Color(#colorLiteral(red: 0.0, green: 0.329, blue: 0.184, alpha: 1)) // #00552F
   static let athleticsDark = Color(#colorLiteral(red: 0.0, green: 0.145, blue: 0.078, alpha: 1)) // #002614

   static let blueJayPrimary = Color(#colorLiteral(red: 0.0745, green: 0.2902, blue: 0.5569, alpha: 1)) // #134A8E
   static let blueJayDark = Color(#colorLiteral(red: 0.1137, green: 0.1765, blue: 0.3608, alpha: 1)) // #1D2D5C

   static let bravesPrimary = Color(#colorLiteral(red: 0.478, green: 0.055, blue: 0.098, alpha: 1)) // #7A0E19
   static let bravesDark = Color(#colorLiteral(red: 0.188, green: 0.027, blue: 0.039, alpha: 1)) // #30070A

   static let brewersPrimary = Color(#colorLiteral(red: 0.0, green: 0.2, blue: 0.4, alpha: 1)) // #003366
   static let brewersDark = Color(#colorLiteral(red: 0.0, green: 0.094, blue: 0.188, alpha: 1)) // #001830

   static let cardinalsPrimary = Color(#colorLiteral(red: 0.835, green: 0.0, blue: 0.184, alpha: 1)) // #D5002F
   static let cardinalsDark = Color(#colorLiteral(red: 0.373, green: 0.0, blue: 0.082, alpha: 1)) // #5F0015

   static let cubsPrimary = Color(#colorLiteral(red: 0.0, green: 0.318, blue: 0.612, alpha: 1)) // #0051A9
   static let cubsDark = Color(#colorLiteral(red: 0.0, green: 0.141, blue: 0.271, alpha: 1)) // #002446

   static let diamondbacksPrimary = Color(#colorLiteral(red: 0.545, green: 0.0, blue: 0.0, alpha: 1)) // #8B0000
   static let diamondbacksDark = Color(#colorLiteral(red: 0.247, green: 0.0, blue: 0.0, alpha: 1)) // #3F0000

   static let dodgersPrimary = Color(#colorLiteral(red: 0.0, green: 0.188, blue: 0.529, alpha: 1)) // #003087
   static let dodgersDark = Color(#colorLiteral(red: 0.047, green: 0.137, blue: 0.251, alpha: 1)) // #0C2340

   static let giantsPrimary = Color(#colorLiteral(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)) // #000000
   static let giantsDark = Color(#colorLiteral(red: 0.239, green: 0.141, blue: 0.0, alpha: 1)) // #3D2400

   static let guardiansPrimary = Color(#colorLiteral(red: 0.0, green: 0.22, blue: 0.396, alpha: 1)) // #003866
   static let guardiansDark = Color(#colorLiteral(red: 0.0, green: 0.098, blue: 0.176, alpha: 1)) // #001931

   static let marinersPrimary = Color(#colorLiteral(red: 0.0, green: 0.404, blue: 0.439, alpha: 1)) // #006774
   static let marinersDark = Color(#colorLiteral(red: 0.0, green: 0.176, blue: 0.192, alpha: 1)) // #002D31

   static let marlinsPrimary = Color(#colorLiteral(red: 0.0, green: 0.729, blue: 0.831, alpha: 1)) // #00BAD4
   static let marlinsDark = Color(#colorLiteral(red: 0.0, green: 0.263, blue: 0.306, alpha: 1)) // #00434E

   static let metsPrimary = Color(#colorLiteral(red: 0.0, green: 0.38, blue: 0.655, alpha: 1)) // #0061A7
   static let metsDark = Color(#colorLiteral(red: 0.0, green: 0.169, blue: 0.292, alpha: 1)) // #002B4A

   static let nationalsPrimary = Color(#colorLiteral(red: 0.741, green: 0.0, blue: 0.188, alpha: 1)) // #BD0030
   static let nationalsDark = Color(#colorLiteral(red: 0.298, green: 0.0, blue: 0.078, alpha: 1)) // #4C0014

   static let nyyPrimary = Color(#colorLiteral(red: 0.0, green: 0.188, blue: 0.529, alpha: 1)) // #003087
   static let nyyDark = Color(#colorLiteral(red: 0.047, green: 0.137, blue: 0.251, alpha: 1)) // #0C2340

   static let oriolesPrimary = Color(#colorLiteral(red: 1.0, green: 0.353, blue: 0.0, alpha: 1)) // #FF5A00
   static let oriolesDark = Color(#colorLiteral(red: 0.376, green: 0.125, blue: 0.0, alpha: 1)) // #601F00

   static let padresPrimary = Color(#colorLiteral(red: 0.376, green: 0.29, blue: 0.118, alpha: 1)) // #604A1E
   static let padresDark = Color(#colorLiteral(red: 0.204, green: 0.157, blue: 0.086, alpha: 1)) // #342814

   static let philliesPrimary = Color(#colorLiteral(red: 0.678, green: 0.106, blue: 0.204, alpha: 1)) // #AD1B34
   static let philliesDark = Color(#colorLiteral(red: 0.298, green: 0.047, blue: 0.094, alpha: 1)) // #4C0C18

   static let piratesPrimary = Color(#colorLiteral(red: 0.996, green: 0.835, blue: 0.0, alpha: 1)) // #FDD400
   static let piratesDark = Color(#colorLiteral(red: 0.4, green: 0.337, blue: 0.0, alpha: 1)) // #665600

   static let rangersPrimary = Color(#colorLiteral(red: 0.0, green: 0.212, blue: 0.455, alpha: 1)) // #003672
   static let rangersDark = Color(#colorLiteral(red: 0.0, green: 0.094, blue: 0.2, alpha: 1)) // #001830

   static let raysPrimary = Color(#colorLiteral(red: 0.0, green: 0.345, blue: 0.651, alpha: 1)) // #0058A6
   static let raysDark = Color(#colorLiteral(red: 0.0, green: 0.153, blue: 0.29, alpha: 1)) // #00274A

   static let redsPrimary = Color(#colorLiteral(red: 0.855, green: 0.118, blue: 0.129, alpha: 1)) // #DA1E21
   static let redsDark = Color(#colorLiteral(red: 0.373, green: 0.051, blue: 0.055, alpha: 1)) // #5F0D0E

   static let rockiesPrimary = Color(#colorLiteral(red: 0.345, green: 0.267, blue: 0.541, alpha: 1)) // #58448A
   static let rockiesDark = Color(#colorLiteral(red: 0.169, green: 0.133, blue: 0.263, alpha: 1)) // #2B2243

   static let royalsPrimary = Color(#colorLiteral(red: 0.0, green: 0.318, blue: 0.659, alpha: 1)) // #0053A8
   static let royalsDark = Color(#colorLiteral(red: 0.0, green: 0.145, blue: 0.301, alpha: 1)) // #00254D

   static let tigersPrimary = Color(#colorLiteral(red: 0.0, green: 0.18, blue: 0.333, alpha: 1)) // #002E55
   static let tigersDark = Color(#colorLiteral(red: 0.0, green: 0.082, blue: 0.149, alpha: 1)) // #001529

   static let twinsPrimary = Color(#colorLiteral(red: 0.216, green: 0.0, blue: 0.373, alpha: 1)) // #370060
   static let twinsDark = Color(#colorLiteral(red: 0.098, green: 0.0, blue: 0.169, alpha: 1)) // #19002B

   static let whiteSoxPrimary = Color(#colorLiteral(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)) // #000000
   static let whiteSoxDark = Color(#colorLiteral(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)) // #333333

}

   // UTILIZATION: Color(rgb: 220, 123, 35)
extension Color {
   init(rgb: Int...) {
	  if rgb.count == 3 {
		 self.init(red: Double(rgb[0]) / 255.0, green: Double(rgb[1]) / 255.0, blue: Double(rgb[2]) / 255.0)
	  } else {
		 self.init(red: 1.0, green: 0.5, blue: 1.0)
	  }
   }
}
