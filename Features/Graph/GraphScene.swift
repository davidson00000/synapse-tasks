#if os(iOS)
import SpriteKit
import UIKit

final class GraphScene: SKScene {
    struct NodeData: Hashable {
        let id: UUID
        var title: String
        var position: CGPoint
        var locked: Bool
    }

    struct EdgeData: Hashable {
        let id: UUID
        let from: UUID
        let to: UUID
    }

    private let contentNode = SKNode()
    private let edgesLayer = SKNode()
    private let nodesLayer = SKNode()
    private let graphCamera = SKCameraNode()
    private let minimapBorder = SKShapeNode(rectOf: CGSize(width: 140, height: 100), cornerRadius: 12)

    private var nodeSprites: [UUID: SKShapeNode] = [:]
    private var labelSprites: [UUID: SKLabelNode] = [:]
    private var nodeCache: [UUID: NodeData] = [:]
    private var edgeCache: [EdgeData] = []

    private weak var hostingView: SKView?
    private var pinchRecognizer: UIPinchGestureRecognizer?
    private var panRecognizer: UIPanGestureRecognizer?
    private var longPressRecognizer: UILongPressGestureRecognizer?

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor.systemBackground
        isUserInteractionEnabled = true
        setupSceneGraph()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        backgroundColor = UIColor.systemBackground
        isUserInteractionEnabled = true
        setupSceneGraph()
    }

    private func setupSceneGraph() {
        addChild(contentNode)
        contentNode.addChild(edgesLayer)
        contentNode.addChild(nodesLayer)

        camera = graphCamera
        addChild(graphCamera)
        configureMinimap()
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        hostingView = view
        attachGestureRecognizers(to: view)
        layoutMinimap()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        detachGestureRecognizers()
        hostingView = nil
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutMinimap()
    }

    func updateGraph(nodes: [NodeData], edges: [EdgeData]) {
        nodeCache = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        edgeCache = edges
        redrawEdges()
        redrawNodes()
    }

    private func redrawNodes() {
        nodesLayer.removeAllChildren()
        nodeSprites.removeAll()
        labelSprites.removeAll()

        for node in nodeCache.values {
            let circle = SKShapeNode(circleOfRadius: 40)
            circle.fillColor = UIColor.systemBlue.withAlphaComponent(0.15)
            circle.strokeColor = UIColor.systemBlue
            circle.lineWidth = node.locked ? 4 : 2
            circle.lineDashPattern = node.locked ? [NSNumber(value: 6), NSNumber(value: 3)] : nil
            circle.position = node.position

            let label = SKLabelNode(text: node.title)
            label.fontName = UIFont.preferredFont(forTextStyle: .caption1).fontName
            label.fontSize = 13
            label.fontColor = UIColor.label
            label.verticalAlignmentMode = .center
            label.position = node.position

            nodesLayer.addChild(circle)
            nodesLayer.addChild(label)
            labelSprites[node.id] = label
            nodeSprites[node.id] = circle
        }
    }

    private func redrawEdges() {
        edgesLayer.removeAllChildren()

        for edge in edgeCache {
            guard
                let from = nodeCache[edge.from]?.position,
                let to = nodeCache[edge.to]?.position
            else { continue }

            let path = CGMutablePath()
            path.move(to: from)
            path.addLine(to: to)

            let line = SKShapeNode(path: path)
            line.strokeColor = UIColor.secondaryLabel
            line.lineWidth = 1.5
            line.lineCap = .round
            edgesLayer.addChild(line)
        }
    }

    private func configureMinimap() {
        minimapBorder.strokeColor = UIColor.systemGray
        minimapBorder.lineWidth = 1
        minimapBorder.fillColor = UIColor.systemBackground.withAlphaComponent(0.3)
        minimapBorder.zPosition = 1000
        minimapBorder.name = "minimap"
        graphCamera.addChild(minimapBorder)
    }

    private func layoutMinimap() {
        let inset: CGFloat = 20
        minimapBorder.position = CGPoint(
            x: -size.width / 2 + minimapBorder.frame.width / 2 + inset,
            y: -size.height / 2 + minimapBorder.frame.height / 2 + inset
        )
    }

    // MARK: - Gesture Handling

    private func attachGestureRecognizers(to view: SKView) {
        if pinchRecognizer == nil {
            let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            recognizer.cancelsTouchesInView = false
            view.addGestureRecognizer(recognizer)
            pinchRecognizer = recognizer
        }

        if panRecognizer == nil {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.maximumNumberOfTouches = 2
            recognizer.cancelsTouchesInView = false
            view.addGestureRecognizer(recognizer)
            panRecognizer = recognizer
        }

        if longPressRecognizer == nil {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            recognizer.minimumPressDuration = 0.5
            view.addGestureRecognizer(recognizer)
            longPressRecognizer = recognizer
        }
    }

    private func detachGestureRecognizers() {
        if let recognizer = pinchRecognizer {
            hostingView?.removeGestureRecognizer(recognizer)
        }
        if let recognizer = panRecognizer {
            hostingView?.removeGestureRecognizer(recognizer)
        }
        if let recognizer = longPressRecognizer {
            hostingView?.removeGestureRecognizer(recognizer)
        }
        pinchRecognizer = nil
        panRecognizer = nil
        longPressRecognizer = nil
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let camera = camera else { return }
        if recognizer.state == .changed {
            let newScale = camera.xScale / recognizer.scale
            camera.setScale(newScale.clamped(to: 0.4...2.5))
            recognizer.scale = 1.0
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let camera = camera, let view = hostingView else { return }
        let translation = recognizer.translation(in: view)
        camera.position.x -= translation.x * camera.xScale
        camera.position.y += translation.y * camera.yScale
        recognizer.setTranslation(.zero, in: view)
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let view = hostingView else { return }
        let locationInView = recognizer.location(in: view)
        let scenePoint = convertPoint(fromView: locationInView)
        let location = nodesLayer.convert(scenePoint, from: self)

        guard let hit = nodeSprites.first(where: { $0.value.contains(location) }) else { return }
        toggleLock(for: hit.key)
    }

    private func toggleLock(for id: UUID) {
        guard var node = nodeCache[id], let shape = nodeSprites[id] else { return }
        node.locked.toggle()
        nodeCache[id] = node
        shape.lineWidth = node.locked ? 4 : 2
        shape.lineDashPattern = node.locked ? [NSNumber(value: 6), NSNumber(value: 3)] : nil
        shape.strokeColor = node.locked ? UIColor.systemRed : UIColor.systemBlue
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
#endif
