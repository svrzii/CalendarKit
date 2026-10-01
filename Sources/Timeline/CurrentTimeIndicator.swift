import UIKit

@objc public final class CurrentTimeIndicator: UIView {
  private let padding : CGFloat = 3
  private let leadingInset: CGFloat = 53

  public var calendar: Calendar = Calendar.autoupdatingCurrent

  /// Determines if times should be displayed in a 24 hour format. Defaults to the current locale's setting
  public var is24hClock : Bool = true

  public var date = Date() {
    didSet {
      updateTimeText()
    }
  }

  private var circle = UIView()
  private var line = UIView()
  private let timeLabel = UILabel()

  private var style = CurrentTimeIndicatorStyle()

  override init(frame: CGRect) {
    super.init(frame: frame)
    configure()
  }

  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    configure()
  }

  private func configure() {
    [circle, line, timeLabel].forEach {
      addSubview($0)
    }
    timeLabel.textAlignment = .right

    updateStyle(style)
    isUserInteractionEnabled = false
  }

  override public func layoutSubviews() {
    super.layoutSubviews()
    if style.showsTimeLabel {
      layoutWithTimeLabel()
      return
    }
    timeLabel.isHidden = true
    line.frame = {
        
        let x: CGFloat
        let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        if rightToLeft {
            x = 0
        } else {
            x = leadingInset - padding
        }
        
        return CGRect(x: x, y: bounds.height / 2, width: bounds.width - leadingInset, height: 1)
    }()

    circle.frame = {
        
        let x: CGFloat
        if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
            x = bounds.width - leadingInset - 10
        } else {
            x = leadingInset + 1
        }
        
        return CGRect(x: x, y: 0, width: 6, height: 6)
    }()
    circle.center.y = line.center.y
    circle.layer.cornerRadius = circle.bounds.height / 2
  }

  private func layoutWithTimeLabel() {
    let dotLeading = style.labelWidth + 6
    timeLabel.isHidden = false
    timeLabel.frame = CGRect(x: 0, y: (bounds.height - 16) / 2, width: style.labelWidth, height: 16)
    circle.frame = CGRect(x: dotLeading, y: 0, width: style.dotSize, height: style.dotSize)
    circle.center.y = bounds.height / 2
    circle.layer.cornerRadius = style.dotSize / 2
    line.frame = CGRect(x: dotLeading + style.dotSize / 2, y: (bounds.height - style.lineHeight) / 2, width: bounds.width - dotLeading - style.dotSize / 2, height: style.lineHeight)
  }

  private func updateTimeText() {
    guard style.showsTimeLabel else {
      return
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    formatter.dateFormat = is24hClock ? "HH:mm" : "h:mm a"
    timeLabel.text = formatter.string(from: date)
  }

  func updateStyle(_ newStyle: CurrentTimeIndicatorStyle) {
    style = newStyle
    circle.backgroundColor = style.color
    line.backgroundColor = style.color
    timeLabel.font = style.font
    timeLabel.textColor = style.color
    timeLabel.backgroundColor = style.labelBackgroundColor
    
    switch style.dateStyle {
    case .twelveHour:
        is24hClock = false
        break
    case .twentyFourHour:
        is24hClock = true
        break
    default:
        is24hClock = Locale.autoupdatingCurrent.uses24hClock()
        break
    }
    updateTimeText()
    setNeedsLayout()
  }
}
