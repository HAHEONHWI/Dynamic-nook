import CoreGraphics

enum PanelPositioner {
    static func frame(panelSize: CGSize, screenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - panelSize.height,
            width: panelSize.width,
            height: panelSize.height
        ).integral
    }
}
