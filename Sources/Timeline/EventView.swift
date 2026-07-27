import UIKit

open class EventView: UIView {
  public var descriptor: EventDescriptor?
  public var color = SystemColors.label

	private let subtitleRowHeight: CGFloat = 14
	private let avatarRowHeight: CGFloat = 16
	private let avatarSize: CGFloat = 14
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
    return view
  }()

	public private(set) lazy var subtitleLabel: UILabel = {
		let label = UILabel()
		label.isUserInteractionEnabled = false
		label.numberOfLines = 1
		label.lineBreakMode = .byTruncatingTail
		label.font = .systemFont(ofSize: 10)
		return label
	}()

	public private(set) lazy var avatarsStackView: UIStackView = {
		let stack = UIStackView()
		stack.isUserInteractionEnabled = false
		stack.axis = .horizontal
		stack.alignment = .center
		stack.spacing = 2
		return stack
	}()

	public private(set) lazy var cardView: UIView = {
		let view = UIView()
		view.isUserInteractionEnabled = false
		view.backgroundColor = .white
		return view
	}()
	
	public private(set) lazy var colorView: UIView = {
		let view = UIView()
		view.isUserInteractionEnabled = false
		view.backgroundColor = .white
		return view
	}()

  /// Resize Handle views showing up when editing the event.
  /// The top handle has a tag of `0` and the bottom has a tag of `1`
  public private(set) lazy var eventResizeHandles = [EventResizeHandleView(), EventResizeHandleView()]

  override public init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  private func configure() {
	layer.cornerRadius = 5
    color = tintColor
	  
	cardView.frame = CGRect(x: 0, y: 2, width: bounds.width, height: bounds.height - 2)
	colorView.frame = bounds
	colorView.layer.cornerRadius = 5
	colorView.clipsToBounds = true
	insertSubview(colorView, at: 0)

	cardView.layer.cornerRadius = 4
	insertSubview(cardView, at: 1)
	  
    colorView.layer.shadowColor = UIColor.black.cgColor
    colorView.layer.shadowOffset = CGSize(width: 0.0, height: 0.5)
    colorView.layer.shadowRadius = 5
    colorView.layer.shadowOpacity = 0.5
    colorView.layer.masksToBounds = false
	  
	addSubview(textView)
	addSubview(subtitleLabel)
	addSubview(avatarsStackView)

    for (idx, handle) in eventResizeHandles.enumerated() {
      handle.tag = idx
      addSubview(handle)
    }
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
	subtitleLabel.attributedText = event.subtitleAttributedText

	avatarsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
	for image in event.avatarImages ?? [] {
		let imageView = UIImageView(image: image)
		imageView.translatesAutoresizingMaskIntoConstraints = false
		imageView.contentMode = .scaleAspectFill
		imageView.layer.cornerRadius = avatarSize / 2
		imageView.layer.masksToBounds = true
		imageView.widthAnchor.constraint(equalToConstant: avatarSize).isActive = true
		imageView.heightAnchor.constraint(equalToConstant: avatarSize).isActive = true
		avatarsStackView.addArrangedSubview(imageView)
	}
    descriptor = event
	cardView.backgroundColor = event.cardBackgroundColor.withAlphaComponent(0.95)
	colorView.backgroundColor = event.backgroundColor
	colorView.layer.shadowColor = event.shadowColor.cgColor

	backgroundColor = .clear
    color = event.color
    eventResizeHandles.forEach{
      $0.borderColor =  event.color
      $0.isHidden = event.editedEvent == nil
    }
    drawsShadow = event.editedEvent != nil
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

  override open func layoutSubviews() {
    super.layoutSubviews()
	cardView.frame = CGRect(x: 0, y: 3, width: bounds.width, height: bounds.height - 3)
	colorView.frame = bounds
    textView.frame = {
        if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
            return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width - 3, height: bounds.height)
        } else {
			let textViewY = bounds.height >= 24 ? bounds.minY + 5 : bounds.minY + 1
			
			return CGRect(x: bounds.minX, y: textViewY, width: bounds.width, height: bounds.height - textViewY * 2)
        }
    }()
    if frame.minY < 0 {
      var textFrame = textView.frame;
      textFrame.origin.y = frame.minY * -1;
      textFrame.size.height += frame.minY;
      textView.frame = textFrame;
    }
	layoutSubtitleAndAvatars()
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
    }
  }

	private func layoutSubtitleAndAvatars() {
		let hasSubtitle = descriptor?.subtitleAttributedText != nil
		let hasAvatars = !(descriptor?.avatarImages?.isEmpty ?? true)

		guard hasSubtitle || hasAvatars else {
			subtitleLabel.isHidden = true
			avatarsStackView.isHidden = true
			return
		}

		let titleHeight = min(textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)).height, textView.frame.height)
		var y = textView.frame.minY + titleHeight

		let showSubtitle = hasSubtitle && bounds.maxY - y >= subtitleRowHeight + rowSpacing
		subtitleLabel.isHidden = !showSubtitle
		if showSubtitle {
			y += rowSpacing
			subtitleLabel.frame = CGRect(x: textView.frame.minX, y: y, width: textView.frame.width, height: subtitleRowHeight)
			y += subtitleRowHeight
		}

		let showAvatars = hasAvatars && bounds.width >= avatarSize + 4 && bounds.maxY - y >= avatarRowHeight + rowSpacing
		avatarsStackView.isHidden = !showAvatars
		if showAvatars {
			y += rowSpacing
			avatarsStackView.frame = CGRect(x: textView.frame.minX, y: y, width: textView.frame.width, height: avatarRowHeight)
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
