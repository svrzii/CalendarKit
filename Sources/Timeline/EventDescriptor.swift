import Foundation
import UIKit

public protocol EventDescriptor: AnyObject {
  var dateInterval: DateInterval {get set}
  var isAllDay: Bool {get}
  var text: String {get}
  var attributedText: NSAttributedString? {get}
  var subtitleAttributedText: NSAttributedString? {get}
  var avatarImages: [UIImage]? {get}
  var lineBreakMode: NSLineBreakMode? {get}
  var font : UIFont {get}
  var color: UIColor {get}
  var textColor: UIColor {get}
  var backgroundColor: UIColor {get}
  var cardBackgroundColor: UIColor {get}
  var shadowColor: UIColor {get}
  var editedEvent: EventDescriptor? {get set}
  func makeEditable() -> Self
  func commitEditing()
  var icon: UIImage? {get}
  var timeText: String? {get}
  var startTimeText: String? {get}
  var showsCheckbox: Bool {get}
  var isChecked: Bool {get}
  var checkboxColor: UIColor {get}
  var borderColor: UIColor {get}
}

public extension EventDescriptor {
  var icon: UIImage? { nil }
  var timeText: String? { nil }
  var startTimeText: String? { nil }
  var showsCheckbox: Bool { false }
  var isChecked: Bool { false }
  var checkboxColor: UIColor { color }
  var borderColor: UIColor { color.withAlphaComponent(0.22) }
}
