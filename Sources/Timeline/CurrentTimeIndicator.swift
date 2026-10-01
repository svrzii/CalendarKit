import UIKit

@objc public final class CurrentTimeIndicator: UIView {
  private let padding : CGFloat = 3
  private let leadingInset: CGFloat = 53

  public var calendar: Calendar = Calendar.autoupdatingCurrent

  /// Determines if times should be displayed in a 24 hour format. Defaults to the current locale's setting
  public var is24hClock : Bool = true

  public var date = Date()

  private var circle = UIView()
  private var line = UIView()

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
    [circle, line].forEach {
      addSubview($0)
    }

    updateStyle(style)
    isUserInteractionEnabled = false
  }

  override public func layoutSubviews() {
    super.layoutSubviews()
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

  func updateStyle(_ newStyle: CurrentTimeIndicatorStyle) {
    style = newStyle
    circle.backgroundColor = style.color
    line.backgroundColor = style.color
    
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
  }
}
