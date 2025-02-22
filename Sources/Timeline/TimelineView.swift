import UIKit

public protocol TimelineViewDelegate: AnyObject {
	func timelineView(_ timelineView: TimelineView, didTapAt date: Date)
	func timelineView(_ timelineView: TimelineView, didLongPressAt date: Date)
	func timelineView(_ timelineView: TimelineView, didTap event: EventView)
	func timelineView(_ timelineView: TimelineView, didLongPress event: EventView)
}

public final class TimelineView: UIView {
	public weak var delegate: TimelineViewDelegate?
	
	public var date = Date() {
		didSet {
			setNeedsLayout()
		}
	}
	
	private var currentTime: Date {
		var cal = Calendar(identifier: Calendar.Identifier.gregorian)
		
		guard let utcTimeZone = TimeZone(abbreviation: "UTC") else {
			return Date()
		}
		
		cal.timeZone = utcTimeZone
		
		let hoursFromUTCTime = TimeZone.current.secondsFromGMT() / 60 / 60
		guard let date = cal.date(byAdding: .hour, value: hoursFromUTCTime, to: Date()) else {
			return Date()
		}
		
		return date
	}
	
	public var offset: CGFloat = 0
	private var eventViews = [EventView]()
	public private(set) var regularLayoutAttributes = [EventLayoutAttributes]()
	public private(set) var allDayLayoutAttributes = [EventLayoutAttributes]()
	
	public func reload(_ events: [EventDescriptor], date: Date) {
		self.date = date
		let end = calendar.date(byAdding: .day, value: 1, to: date)!
		let day = DateInterval(start: date, end: end)
		let validEvents = events.filter{$0.dateInterval.intersects(day)}
		layoutAttributes = validEvents.map(EventLayoutAttributes.init)
		setNeedsDisplay()
	}
	
	public var layoutAttributes: [EventLayoutAttributes] {
		get {
			allDayLayoutAttributes + regularLayoutAttributes
		}
		set {
			
			// update layout attributes by separating all-day from non-all-day events
			allDayLayoutAttributes.removeAll()
			regularLayoutAttributes.removeAll()
			sortedEvents.removeAll()
			numberOfRecalculations = 0
			for anEventLayoutAttribute in newValue {
				let eventDescriptor = anEventLayoutAttribute.descriptor
				if eventDescriptor.isAllDay {
					allDayLayoutAttributes.append(anEventLayoutAttribute)
				} else {
					regularLayoutAttributes.append(anEventLayoutAttribute)
				}
			}
			
			recalculateEventLayout()
			prepareEventViews()
			allDayView.events = allDayLayoutAttributes.map { $0.descriptor }
			allDayView.isHidden = allDayLayoutAttributes.count == 0
			allDayView.scrollToBottom()
			
			setNeedsLayout()
		}
	}
	private var pool = ReusePool<EventView>()
	
	public var firstEventYPosition: CGFloat? {
		let first = regularLayoutAttributes.sorted{$0.frame.origin.y < $1.frame.origin.y}.first
		guard let firstEvent = first else {return nil}
		let firstEventPosition = firstEvent.frame.origin.y
		let beginningOfDayPosition = dateToY(date)
		return max(firstEventPosition, beginningOfDayPosition)
	}
	
	private lazy var nowLine: CurrentTimeIndicator = CurrentTimeIndicator()
	
	private var allDayViewTopConstraint: NSLayoutConstraint?
	private lazy var allDayView: AllDayView = {
		let allDayView = AllDayView(frame: CGRect.zero)
		
		allDayView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(allDayView)
		
		allDayViewTopConstraint = allDayView.topAnchor.constraint(equalTo: topAnchor, constant: 0)
		allDayViewTopConstraint?.isActive = true
		
		allDayView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0).isActive = true
		allDayView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0).isActive = true
		
		return allDayView
	}()
	
	var allDayViewHeight: CGFloat {
		allDayView.bounds.height
	}
	
	var style = TimelineStyle()
	private var horizontalEventInset: CGFloat = 3
	
	public var fullHeight: CGFloat {
		style.verticalInset * 2 + style.verticalDiff * 24
	}
	
	public var calendarWidth: CGFloat {
		bounds.width - style.leadingInset
	}
	
	public private(set) var is24hClock = true {
		didSet {
			setNeedsDisplay()
		}
	}
	
	public var calendar: Calendar = Calendar.autoupdatingCurrent {
		didSet {
			calendar.timeZone = TimeZone(abbreviation: "UTC")!
			eventEditingSnappingBehavior.calendar = calendar
			nowLine.calendar = calendar
			regenerateTimeStrings()
			setNeedsLayout()
		}
	}
	
	public var eventEditingSnappingBehavior: EventEditingSnappingBehavior = SnapTo15MinuteIntervals() {
		didSet {
			eventEditingSnappingBehavior.calendar = calendar
		}
	}
	
	private var times: [String] {
		is24hClock ? _24hTimes : _12hTimes
	}
	
	private lazy var _12hTimes: [String] = TimeStringsFactory(calendar).make12hStrings()
	private lazy var _24hTimes: [String] = TimeStringsFactory(calendar).make24hStrings()
	
	private func regenerateTimeStrings() {
		let factory = TimeStringsFactory(calendar)
		_12hTimes = factory.make12hStrings()
		_24hTimes = factory.make24hStrings()
	}
	
	public lazy private(set) var longPressGestureRecognizer = UILongPressGestureRecognizer(target: self,
																						   action: #selector(longPress(_:)))
	
	public lazy private(set) var tapGestureRecognizer = UITapGestureRecognizer(target: self,
																			   action: #selector(tap(_:)))
	
	private var isToday: Bool {
		calendar.isDateInToday(date)
	}
	
	// MARK: - Initialization
	
	public init() {
		super.init(frame: .zero)
		frame.size.height = fullHeight
		configure()
	}
	
	override public init(frame: CGRect) {
		super.init(frame: frame)
		configure()
	}
	
	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		configure()
	}
	
	private func configure() {
		contentScaleFactor = 1
		layer.contentsScale = 1
		contentMode = .redraw
		backgroundColor = .white
		addSubview(nowLine)
		
		// Add long press gesture recognizer
		addGestureRecognizer(longPressGestureRecognizer)
		addGestureRecognizer(tapGestureRecognizer)
		
		// Scheduling timer to Call the function "updateCounting" with the interval of 1 seconds
		timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.updateCounting), userInfo: nil, repeats: true)
	}
	
	var allowRecalculation = false
	@objc func updateCounting(){
		self.allowRecalculation = true
	}
	// MARK: - Event Handling
	
	@objc private func longPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
		if (gestureRecognizer.state == .began) {
			// Get timeslot of gesture location
			let pressedLocation = gestureRecognizer.location(in: self)
			if let eventView = findEventView(at: pressedLocation) {
				delegate?.timelineView(self, didLongPress: eventView)
			} else {
				delegate?.timelineView(self, didLongPressAt: yToDate(pressedLocation.y))
			}
		}
	}
	
	@objc private func tap(_ sender: UITapGestureRecognizer) {
		let pressedLocation = sender.location(in: self)
		if let eventView = findEventView(at: pressedLocation) {
			delegate?.timelineView(self, didTap: eventView)
		} else {
			delegate?.timelineView(self, didTapAt: yToDate(pressedLocation.y))
		}
	}
	
	private func findEventView(at point: CGPoint) -> EventView? {
		for eventView in allDayView.eventViews {
			let frame = eventView.convert(eventView.bounds, to: self)
			if frame.contains(point) {
				return eventView
			}
		}
		
		for eventView in eventViews.reversed() {
			let frame = eventView.frame
			if frame.contains(point) {
				return eventView
			}
		}
		
		return nil
	}
	
	
	/**
	 Custom implementation of the hitTest method is needed for the tap gesture recognizers
	 located in the AllDayView to work.
	 Since the AllDayView could be outside of the Timeline's bounds, the touches to the EventViews
	 are ignored.
	 In the custom implementation the method is recursively invoked for all of the subviews,
	 regardless of their position in relation to the Timeline's bounds.
	 */
	public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		for subview in allDayView.subviews {
			if let subSubView = subview.hitTest(convert(point, to: subview), with: event) {
				return subSubView
			}
		}
		return super.hitTest(point, with: event)
	}
	
	// MARK: - Style
	
	public func updateStyle(_ newStyle: TimelineStyle) {
		style = newStyle
		allDayView.updateStyle(style.allDayStyle)
		nowLine.updateStyle(style.timeIndicator)
		
		switch style.dateStyle {
		case .twelveHour:
			is24hClock = false
		case .twentyFourHour:
			is24hClock = true
		default:
			is24hClock = calendar.locale?.uses24hClock() ?? Locale.autoupdatingCurrent.uses24hClock()
		}
		
		backgroundColor = style.backgroundColor
		setNeedsDisplay()
	}
	
	// MARK: - Background Pattern
	
	public var accentedDate: Date?
	
	override public func draw(_ rect: CGRect) {
		super.draw(rect)
		
		var hourToRemoveIndex = -1
		
		var accentedHour = -1
		var accentedMinute = -1
		
		if let accentedDate = accentedDate {
			accentedHour = eventEditingSnappingBehavior.accentedHour(for: accentedDate)
			accentedMinute = eventEditingSnappingBehavior.accentedMinute(for: accentedDate)
		}
		
		if isToday {
			let minute = component(component: .minute, from: currentTime)
			let hour = component(component: .hour, from: currentTime)
			if minute > 39 {
				hourToRemoveIndex = hour + 1
			} else if minute < 21 {
				hourToRemoveIndex = hour
			}
		}
		
		let mutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
		mutableParagraphStyle.lineBreakMode = .byWordWrapping
		mutableParagraphStyle.alignment = .right
		let paragraphStyle = mutableParagraphStyle.copy() as! NSParagraphStyle
		
		let attributes = [NSAttributedString.Key.paragraphStyle: paragraphStyle,
						  NSAttributedString.Key.foregroundColor: self.style.timeColor,
						  NSAttributedString.Key.font: style.font] as [NSAttributedString.Key : Any]
		
		let scale = UIScreen.main.scale
		let hourLineHeight = 1 / UIScreen.main.scale
		
		let center: CGFloat
		if Int(scale) % 2 == 0 {
			center = 1 / (scale * 2)
		} else {
			center = 0
		}
		
		let offset = 0.5 - center
		
		for (hour, time) in times.enumerated() {
			let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
			
			let hourFloat = CGFloat(hour)
			let context = UIGraphicsGetCurrentContext()
			context!.interpolationQuality = .none
			context?.saveGState()
			context?.setStrokeColor(style.separatorColor.cgColor)
			context?.setLineWidth(hourLineHeight)
			let xStart: CGFloat = {
				if rightToLeft {
					return bounds.width - 53
				} else {
					return 53
				}
			}()
			let xEnd: CGFloat = {
				if rightToLeft {
					return 0
				} else {
					return bounds.width
				}
			}()
			let y = style.verticalInset + hourFloat * style.verticalDiff + offset
			context?.beginPath()
			context?.move(to: CGPoint(x: xStart, y: y))
			context?.addLine(to: CGPoint(x: xEnd, y: y))
			context?.strokePath()
			context?.restoreGState()
			
			if hour == hourToRemoveIndex { continue }
			
			let fontSize = style.font.pointSize
			let timeRect: CGRect = {
				var x: CGFloat
				if rightToLeft {
					x = bounds.width - 53
				} else {
					x = 2
				}
				
				return CGRect(x: x,
							  y: hourFloat * style.verticalDiff + style.verticalInset - 7,
							  width: style.leadingInset - 8,
							  height: fontSize + 2)
			}()
			
			let timeString = NSString(string: time)
			timeString.draw(in: timeRect, withAttributes: attributes)
			
			if accentedMinute == 0 {
				continue
			}
			
			if hour == accentedHour {
				
				var x: CGFloat
				if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
					x = bounds.width - (style.leadingInset + 7)
				} else {
					x = 2
				}
				
				let timeRect = CGRect(x: x, y: hourFloat * style.verticalDiff + style.verticalInset - 7     + style.verticalDiff * (CGFloat(accentedMinute) / 60),
									  width: style.leadingInset - 8, height: fontSize + 2)
				
				let timeString = NSString(string: ":\(accentedMinute)")
				
				timeString.draw(in: timeRect, withAttributes: attributes)
			}
		}
	}
	
	// MARK: - Layout
	
	var timer = Timer()
	var numberOfRecalculations = 0
	override public func layoutSubviews() {
		super.layoutSubviews()
		if self.numberOfRecalculations < 1 || self.allowRecalculation {
			recalculateEventLayout()
			layoutEvents()
			layoutNowLine()
			layoutAllDayEvents()
			self.allowRecalculation = false
			self.numberOfRecalculations += 1
		}
	}
	
	private func layoutNowLine() {
		if !isToday {
			nowLine.alpha = 0
		} else {
			bringSubviewToFront(nowLine)
			nowLine.alpha = 1
			let size = CGSize(width: bounds.size.width, height: 20)
			let rect = CGRect(origin: CGPoint.zero, size: size)
			nowLine.date = currentTime
			nowLine.frame = rect
			nowLine.center.y = dateToY(currentTime)
		}
	}
	
	/// Creates an EventView and places it on the Timeline
	/// - Parameter event: the EventDescriptor based on which an EventView will be placed on the Timeline
	/// - Parameter animated: if true, CalendarKit animates event creation
	public func create(event: EventDescriptor, animated: Bool) {
		let eventView = EventView()
		addSubview(eventView)
		eventView.updateWithDescriptor(event: event)
		// layout algo
		
		//		for handle in eventView.eventResizeHandles {
		//			let panGestureRecognizer = handle.panGestureRecognizer
		//			panGestureRecognizer.addTarget(self, action: #selector(handleResizeHandlePanGesture(_:)))
		//			panGestureRecognizer.cancelsTouchesInView = true
		//		}
		
		
		// algo needs to be extracted to a separate object
		let yStart = self.dateToY(event.dateInterval.start) - self.offset
		let yEnd = self.dateToY(event.dateInterval.end) - self.offset
		
		let rightToLeft = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
		let x = rightToLeft ? 0 : self.style.leadingInset
		let newRect = CGRect(x: x,
							 y: yStart,
							 width: self.calendarWidth,
							 height: yEnd - yStart)
		eventView.frame = newRect
		
		if animated {
			eventView.animateCreation()
		}
		
		eventViews.append(eventView)
		
		//		accentDateForEditedEventView()
	}
	
	private func layoutEvents() {
		if eventViews.isEmpty { return }
		
		for (idx, attributes) in regularLayoutAttributes.enumerated() {
			let descriptor = attributes.descriptor
			let eventView = eventViews[idx]
			eventView.frame = attributes.frame
			
			var x: CGFloat
			if UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft {
				x = bounds.width - attributes.frame.minX - attributes.frame.width
			} else {
				x = attributes.frame.minX
			}
			
			eventView.frame = CGRect(x: x > 65 ? x - abs(style.eventGap) : x,
									 y: attributes.frame.minY,
									 width: x > 65 ? attributes.frame.width + abs(style.eventGap) : (attributes.frame.width),
									 height: max(24, attributes.frame.height))
			eventView.updateWithDescriptor(event: descriptor)
		}
		
		self.eventViews = self.eventViews.sorted(by: {
			guard let eventInterval0 = $0.descriptor?.dateInterval, let eventInterval1 = $1.descriptor?.dateInterval else {
				return false
			}
			
			if eventInterval0.start < eventInterval1.start {
				return true
			} else if eventInterval0.start == eventInterval1.start {
				return eventInterval0.end < eventInterval1.end
			} else {
				return false
			}
		})
		
		
		for eventView in self.eventViews {
			bringSubviewToFront(eventView)
		}
	}
	
	private func layoutAllDayEvents() {
		//add day view needs to be in front of the nowLine
		bringSubviewToFront(allDayView)
	}
	
	/**
	 This will keep the allDayView as a stationary view in its superview
	 
	 - parameter yValue: since the superview is a scrollView, `yValue` is the
	 `contentOffset.y` of the scroll view
	 */
	public func offsetAllDayView(by yValue: CGFloat) {
		if let topConstraint = self.allDayViewTopConstraint {
			topConstraint.constant = yValue
			layoutIfNeeded()
		}
	}
	
	var sortedEvents = [EventLayoutAttributes]()
	
	var eventColums: [[EventLayoutAttributes]] = []
	private func recalculateEventLayout() {
		// only non allDay events need their frames to be set
		if self.sortedEvents.isEmpty {
			self.sortedEvents = self.regularLayoutAttributes.sorted(by: {
				if $0.descriptor.dateInterval.start < $1.descriptor.dateInterval.start {
					return true
				} else if $0.descriptor.dateInterval.start == $1.descriptor.dateInterval.start {
					return $0.descriptor.dateInterval.end < $1.descriptor.dateInterval.end
				} else {
					return false
				}
			})
		}
		
		self.setupColumns(events: self.sortedEvents)
	}
	
	func setupColumns(events: [EventLayoutAttributes]) {
		self.eventColums.removeAll()
		for event in events {
			let position = self.findIntersections(newEvent: event)
			if self.eventColums.indices.contains(position) {
				self.eventColums[position].append(event)
			} else {
				self.eventColums.append([event])
			}
		}
		
		for event in events {
			self.findIntersectionIndexes(newEvent: event)
		}
		
		self.regularLayoutAttributes.removeAll()
		
		for (i, column) in self.eventColums.enumerated() {
			for event in column {
				let startY = dateToY(event.descriptor.dateInterval.start)
				let endY = dateToY(event.descriptor.dateInterval.end)
				let x =  style.leadingInset + CGFloat(i) / CGFloat(event.intersections.count) * calendarWidth
				let equalWidth = calendarWidth / CGFloat(event.intersections.count)
				event.frame = CGRect(x: x, y: startY, width: equalWidth, height: endY - startY)
			}
			
			self.regularLayoutAttributes.append(contentsOf: column)
		}
	}
	
	func findIntersections(newEvent: EventLayoutAttributes) -> Int {
		var nextSection = 0
		for (section, eventArray) in self.eventColums.enumerated() {
			var hasIntersection = false
			for event in eventArray {
				if newEvent.descriptor.dateInterval.intersects(with:event.descriptor.dateInterval) {
					hasIntersection = true
					nextSection += 1
				}
			}
			
			if !hasIntersection {
				return section
			}
		}
		
		return nextSection
	}
	
	func findIntersectionIndexes(newEvent: EventLayoutAttributes) {
		for (section, eventArray) in self.eventColums.enumerated() {
			for event in eventArray {
				if newEvent.descriptor.dateInterval.intersects(with: event.descriptor.dateInterval) {
					if !event.intersections.contains(section) {
						event.intersections.append(section)
					}
					
					if !newEvent.intersections.contains(section) {
						newEvent.intersections.append(section)
					}
				}
			}
		}
	}
	
	func intervalsIntersect(_ interval1: DateInterval, _ interval2: DateInterval) -> Bool {
		return interval1.end > interval2.start && interval1.start < interval2.end
	}
	
	private func prepareEventViews() {
		for eventView in eventViews {
			eventView.removeFromSuperview()
		}
		//    pool.enqueue(views: eventViews)
		self.eventViews.removeAll()
		
		for regular in regularLayoutAttributes {
			create(event: regular.descriptor, animated: false)
		}
	}
	
	public func prepareForReuse() {
		//    pool.enqueue(views: eventViews)
		eventViews.removeAll()
		setNeedsDisplay()
	}
	
	// MARK: - Helpers
	
	public func dateToY(_ date: Date) -> CGFloat {
		let provisionedDate = date.dateOnly(calendar: calendar)
		let timelineDate = self.date.dateOnly(calendar: calendar)
		var dayOffset: CGFloat = 0
		if provisionedDate > timelineDate {
			// Event ending the next day
			dayOffset += 1
		} else if provisionedDate < timelineDate {
			// Event starting the previous day
			dayOffset -= 1
		}
		let fullTimelineHeight = 24 * style.verticalDiff
		let hour = component(component: .hour, from: date)
		let minute = component(component: .minute, from: date)
		
		let hourY = CGFloat(hour) * style.verticalDiff + style.verticalInset
		let minuteY = CGFloat(minute) * style.verticalDiff / 60
		return hourY + minuteY + fullTimelineHeight * dayOffset
	}
	
	public func yToDate(_ y: CGFloat) -> Date {
		let timeValue = y - style.verticalInset
		var hour = Int(timeValue / style.verticalDiff)
		let fullHourPoints = CGFloat(hour) * style.verticalDiff
		let minuteDiff = timeValue - fullHourPoints
		let minute = Int(minuteDiff / style.verticalDiff * 60)
		var dayOffset = 0
		if hour > 23 {
			dayOffset += 1
			hour -= 24
		} else if hour < 0 {
			dayOffset -= 1
			hour += 24
		}
		let offsetDate = calendar.date(byAdding: DateComponents(day: dayOffset),
									   to: date)!
		let newDate = calendar.date(bySettingHour: hour,
									minute: minute.clamped(to: 0...59),
									second: 0,
									of: offsetDate)
		return newDate!
	}
	
	private func component(component: Calendar.Component, from date: Date) -> Int {
		return calendar.component(component, from: date)
	}
	
	private func getDateInterval(date: Date) -> DateInterval {
		let earliestEventMintues = component(component: .minute, from: date)
		let splitMinuteInterval = style.splitMinuteInterval
		let minute = component(component: .minute, from: date)
		let minuteRange = (minute / splitMinuteInterval) * splitMinuteInterval
		let beginningRange = calendar.date(byAdding: .minute, value: -(earliestEventMintues - minuteRange), to: date)!
		let endRange = calendar.date(byAdding: .minute, value: splitMinuteInterval, to: beginningRange)!
		return DateInterval(start: beginningRange, end: endRange)
	}
}

extension DateInterval {
	func intersects(with otherInterval: DateInterval) -> Bool {
		return self.end > otherInterval.start && self.start < otherInterval.end
	}
}
