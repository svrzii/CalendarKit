import UIKit

final class EventCheckboxView: UIControl {
  private let checkLayer = CAShapeLayer()

  override init(frame: CGRect) {
    super.init(frame: frame)
    layer.cornerRadius = 4
    layer.borderWidth = 1.5
    checkLayer.fillColor = nil
    checkLayer.strokeColor = UIColor.white.cgColor
    checkLayer.lineWidth = 1.6
    checkLayer.lineCap = .round
    checkLayer.lineJoin = .round
    let path = UIBezierPath()
    path.move(to: CGPoint(x: 3.5, y: 7.2))
    path.addLine(to: CGPoint(x: 6, y: 9.7))
    path.addLine(to: CGPoint(x: 10.5, y: 4.8))
    checkLayer.path = path.cgPath
    layer.addSublayer(checkLayer)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    checkLayer.frame = bounds
    let scale = bounds.width / 14
    let path = UIBezierPath()
    path.move(to: CGPoint(x: 3.5 * scale, y: 7.2 * scale))
    path.addLine(to: CGPoint(x: 6 * scale, y: 9.7 * scale))
    path.addLine(to: CGPoint(x: 10.5 * scale, y: 4.8 * scale))
    checkLayer.path = path.cgPath
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    return bounds.insetBy(dx: -12, dy: -12).contains(point)
  }

  func configure(color: UIColor, isChecked: Bool) {
    layer.borderColor = color.cgColor
    backgroundColor = isChecked ? color : .white
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    color.resolvedColor(with: traitCollection).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
    checkLayer.strokeColor = (luminance > 0.6 ? UIColor(red: 0x1C / 255, green: 0x1D / 255, blue: 0x29 / 255, alpha: 1) : UIColor.white).cgColor
    checkLayer.isHidden = !isChecked
  }
}

open class EventView: UIView {
  public var descriptor: EventDescriptor?
  public var color = SystemColors.label
  public var onCheckboxTap: (() -> Void)?


	private let avatarSize: CGFloat = 20
	private let avatarOffset: CGFloat = 14
	private let iconSize: CGFloat = 10
	private let ringWidth: CGFloat = 1.5
	private let ringLayer = CALayer()
	private let horizontalPadding: CGFloat = 9
	private let iconTextGap: CGFloat = 6
	private let rowSpacing: CGFloat = 2

  public var contentHeight: CGFloat {
    textView.frame.height
  }

  public private(set) lazy var textView: UITextView = {
    let view = UITextView()
    view.isUserInteractionEnabled = false
    view.backgroundColor = .clear
    view.isScrollEnabled = false
	view.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
	view.textContainer.lineFragmentPadding = 0
	view.textContainer.maximumNumberOfLines = 1
	view.textContainer.lineBreakMode = .byTruncatingTail
    return view
  }()

	public private(set) lazy var timeLabel: UILabel = {
		let label = UILabel()
		label.isUserInteractionEnabled = false
		label.font = .systemFont(ofSize: 11)
		label.textColor = UIColor(red: 0x4E / 255, green: 0x55 / 255, blue: 0x70 / 255, alpha: 1)
		return label
	}()

	public private(set) lazy var subtitleLabel: UILabel = {
		let label = UILabel()
		label.isUserInteractionEnabled = false
		label.lineBreakMode = .byTruncatingTail
		label.numberOfLines = 1
		label.font = .systemFont(ofSize: 12)
		return label
	}()

	public private(set) lazy var avatarsContainerView: UIView = {
		let view = UIView()
		view.isUserInteractionEnabled = false
		view.clipsToBounds = true
		return view
	}()

	public private(set) lazy var iconView: UIImageView = {
		let view = UIImageView()
		view.isUserInteractionEnabled = false
		view.contentMode = .scaleAspectFit
		return view
	}()

	let checkboxView = EventCheckboxView()

	public private(set) lazy var colorView: UIView = {
		let view = UIView()
		view.isUserInteractionEnabled = false
		view.backgroundColor = .white
		return view
	}()

  /// Resize Handle views showing up when editing the event.
  /// The top handle has a tag of `0` and the bottom has a tag of `1`
  public private(set) lazy var eventResizeHandles = [EventResizeHandleView(), EventResizeHandleView()]

	/// Snapshot of the descriptor's subtitle/time/avatars taken in `updateWithDescriptor`.
	/// `layoutSubviews` must not re-read the descriptor: those properties are computed on the
	/// consumer side and can rasterize images or hit the store on every access.
	private var subtitleText: NSAttributedString?
	private var fullTimeText: String?
	private var startTimeText: String?
	private var avatarCount = 0

  override public init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  private func configure() {
	layer.cornerRadius = 10
    color = tintColor

	colorView.frame = bounds
	colorView.layer.cornerRadius = 10
	colorView.clipsToBounds = true
	insertSubview(colorView, at: 0)
	ringLayer.cornerRadius = 10 + ringWidth
	layer.insertSublayer(ringLayer, below: colorView.layer)

	checkboxView.addTarget(self, action: #selector(checkboxTapped), for: .touchUpInside)

	addSubview(iconView)
	addSubview(checkboxView)
	addSubview(textView)
	addSubview(timeLabel)
	addSubview(subtitleLabel)
	addSubview(avatarsContainerView)

    for (idx, handle) in eventResizeHandles.enumerated() {
      handle.tag = idx
      addSubview(handle)
    }
  }

  @objc private func checkboxTapped() {
    onCheckboxTap?()
  }

  public func updateWithDescriptor(event: EventDescriptor) {
    if let attributedText = event.attributedText {
      textView.attributedText = attributedText
    } else {
      textView.text = event.text
	textView.textColor = .black
      textView.font = event.font
    }
    if let lineBreakMode = event.lineBreakMode {
      textView.textContainer.lineBreakMode = lineBreakMode
    }
	subtitleText = event.subtitleAttributedText
	subtitleLabel.attributedText = subtitleText
	fullTimeText = event.timeText
	startTimeText = event.startTimeText

	let ringColor = event.cardBackgroundColor
	let avatarImages = event.avatarImages ?? []
	avatarCount = avatarImages.count
	avatarsContainerView.subviews.forEach { $0.removeFromSuperview() }
	for (index, image) in avatarImages.enumerated() {
		let imageView = UIImageView(image: image)
		imageView.contentMode = .scaleAspectFill
		imageView.frame = CGRect(x: CGFloat(index) * avatarOffset, y: 0, width: avatarSize, height: avatarSize)
		imageView.layer.cornerRadius = avatarSize / 2
		imageView.layer.masksToBounds = true
		imageView.layer.borderWidth = 1.5
		imageView.layer.borderColor = ringColor.cgColor
		// Rounding a bordered image view is an offscreen pass; the avatar never changes size or
		// content once set, so let Core Animation cache the composited result.
		imageView.layer.shouldRasterize = true
		imageView.layer.rasterizationScale = UIScreen.main.scale
		avatarsContainerView.insertSubview(imageView, at: index)
	}

	checkboxView.configure(color: event.checkboxColor, isChecked: event.isChecked)
	checkboxView.isHidden = !event.showsCheckbox
	iconView.image = event.icon
	iconView.tintColor = event.checkboxColor
	iconView.isHidden = event.showsCheckbox || event.icon == nil
    descriptor = event
	colorView.backgroundColor = event.isEnded ? EventView.faded(event.backgroundColor) : event.backgroundColor
	ringLayer.backgroundColor = event.borderColor.cgColor
	alpha = 1
	subviews.filter { $0 !== colorView }.forEach { $0.alpha = event.isEnded ? 0.5 : 1 }

	backgroundColor = .clear
    color = event.color
	let isEdited = event.editedEvent != nil
    eventResizeHandles.forEach{
      $0.borderColor =  color
      $0.isHidden = !isEdited
    }
    drawsShadow = isEdited
    setNeedsDisplay()
    setNeedsLayout()
  }
  
  public func animateCreation() {
    transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
    func scaleAnimation() {
      transform = .identity
    }
    UIView.animate(withDuration: 0.2,
                   delay: 0,
                   usingSpringWithDamping: 0.2,
                   initialSpringVelocity: 10,
                   options: [],
                   animations: scaleAnimation,
                   completion: nil)
  }

  /**
   Custom implementation of the hitTest method is needed for the tap gesture recognizers
   located in the ResizeHandleView to work.
   Since the ResizeHandleView could be outside of the EventView's bounds, the touches to the ResizeHandleView
   are ignored.
   In the custom implementation the method is recursively invoked for all of the subviews,
   regardless of their position in relation to the Timeline's bounds.
   */
  public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    for resizeHandle in eventResizeHandles {
      if let subSubView = resizeHandle.hitTest(convert(point, to: resizeHandle), with: event) {
        return subSubView
      }
    }
    return super.hitTest(point, with: event)
  }

  private var drawsShadow = false

	private static func faded(_ color: UIColor) -> UIColor {
		return UIColor { traits in
			var base: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
			var page: (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
			color.resolvedColor(with: traits).getRed(&base.0, green: &base.1, blue: &base.2, alpha: &base.3)
			UIColor.systemBackground.resolvedColor(with: traits).getRed(&page.0, green: &page.1, blue: &page.2, alpha: &page.3)
			return UIColor(red: (base.0 + page.0) / 2, green: (base.1 + page.1) / 2, blue: (base.2 + page.2) / 2, alpha: 1)
		}
	}

  override open func layoutSubviews() {
    super.layoutSubviews()
	colorView.frame = bounds
	CATransaction.begin()
	CATransaction.setDisableActions(true)
	ringLayer.frame = bounds.insetBy(dx: -ringWidth, dy: -ringWidth)
	CATransaction.commit()
	layoutContent()
    let first = eventResizeHandles.first
    let last = eventResizeHandles.last
    let radius: CGFloat = 40
    let yPad: CGFloat =  -radius / 2
    let width = bounds.width
    let height = bounds.height
    let size = CGSize(width: radius, height: radius)
    first?.frame = CGRect(origin: CGPoint(x: width - radius - layoutMargins.right, y: yPad),
                          size: size)
    last?.frame = CGRect(origin: CGPoint(x: layoutMargins.left, y: height - yPad - radius),
                         size: size)
    
    if drawsShadow {
      applySketchShadow(alpha: 0.13,
                        blur: 10)
    } else {
      // Views come back from the reuse pool, so a shadow left by a previously edited event has to
      // be cleared rather than just not re-applied.
      layer.shadowOpacity = 0
    }
  }

	private func layoutContent() {
		let isShort = bounds.height < 40
		let top: CGFloat = (isShort ? 5 : 7) + max(0, -frame.minY)
		let hasLeading = !iconView.isHidden || !checkboxView.isHidden
		let textX = horizontalPadding + (hasLeading ? iconSize + iconTextGap : 0)

		var timeWidth: CGFloat = 0
		if isShort, let startTimeText = startTimeText, !startTimeText.isEmpty {
			timeLabel.text = startTimeText
			timeWidth = ceil(timeLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width)
		}

		let textWidth = max(1, bounds.width - textX - horizontalPadding - (timeWidth > 0 ? timeWidth + iconTextGap : 0))
		let lineHeight = ceil(textView.sizeThatFits(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)).height)
		textView.frame = CGRect(x: textX, y: top, width: textWidth, height: lineHeight)

		let iconFrame = CGRect(x: horizontalPadding, y: top + (lineHeight - iconSize) / 2, width: iconSize, height: iconSize)
		iconView.frame = iconFrame
		checkboxView.frame = iconFrame

		var y = top + lineHeight
		let bottomLimit = bounds.height - 5

		if isShort {
			timeLabel.isHidden = timeWidth == 0
			timeLabel.frame = CGRect(x: bounds.width - horizontalPadding - timeWidth, y: top + (lineHeight - timeLabel.font.lineHeight) / 2, width: timeWidth, height: ceil(timeLabel.font.lineHeight))
			subtitleLabel.isHidden = true
			avatarsContainerView.isHidden = true
			return
		}

		let contentWidth = max(0, bounds.width - horizontalPadding * 2)

		timeLabel.text = fullTimeText
		let timeHeight = ceil(timeLabel.font.lineHeight)
		let showTime = !(fullTimeText ?? "").isEmpty && y + rowSpacing + timeHeight <= bottomLimit
		timeLabel.isHidden = !showTime
		if showTime {
			y += rowSpacing
			timeLabel.frame = CGRect(x: horizontalPadding, y: y, width: contentWidth, height: timeHeight)
			y += timeHeight
		}

		// subtitleAttributedText's runs don't carry a font attribute, so they render at
		// NSAttributedString's own default font rather than subtitleLabel.font; measure the
		// real single-line height instead of trusting the label's font property.
		let hasSubtitle = (subtitleText?.length ?? 0) > 0
		let subtitleHeight = hasSubtitle ? ceil(subtitleLabel.sizeThatFits(CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude)).height) : 0
		let showSubtitle = hasSubtitle && subtitleHeight > 0 && y + rowSpacing + subtitleHeight <= bottomLimit
		subtitleLabel.isHidden = !showSubtitle
		if showSubtitle {
			y += rowSpacing
			subtitleLabel.frame = CGRect(x: horizontalPadding, y: y, width: contentWidth, height: subtitleHeight)
			y += subtitleHeight
		}

		let avatarsNaturalWidth = avatarCount > 0 ? CGFloat(avatarCount - 1) * avatarOffset + avatarSize : 0
		let showAvatars = avatarCount > 0 && contentWidth >= avatarSize && y + rowSpacing + avatarSize <= bottomLimit
		avatarsContainerView.isHidden = !showAvatars
		if showAvatars {
			y += rowSpacing + 1
			avatarsContainerView.frame = CGRect(x: horizontalPadding, y: y, width: min(avatarsNaturalWidth, contentWidth), height: avatarSize)
		}
	}

  private func applySketchShadow(
    color: UIColor = .black,
    alpha: Float = 0.5,
    x: CGFloat = 0,
    y: CGFloat = 2,
    blur: CGFloat = 4,
    spread: CGFloat = 0)
  {
    layer.shadowColor = color.cgColor
    layer.shadowOpacity = alpha
    layer.shadowOffset = CGSize(width: x, height: y)
    layer.shadowRadius = blur / 2.0
    if spread == 0 {
      layer.shadowPath = nil
    } else {
      let dx = -spread
      let rect = bounds.insetBy(dx: dx, dy: dx)
      layer.shadowPath = UIBezierPath(rect: rect).cgPath
    }
  }
}
