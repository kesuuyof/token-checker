import Foundation

enum CenteredPopoverPositioner {
    static func positionedFrame(
        currentFrame: CGRect,
        anchorFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGRect {
        var frame = currentFrame
        let centeredX = anchorFrame.midX - (currentFrame.width / 2)
        let minX = visibleFrame.minX
        let maxX = visibleFrame.maxX - currentFrame.width
        frame.origin.x = min(max(centeredX, minX), maxX)
        let minY = visibleFrame.minY
        let maxY = visibleFrame.maxY - currentFrame.height
        frame.origin.y = min(max(currentFrame.origin.y, minY), maxY)
        return frame
    }
}
