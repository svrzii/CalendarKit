import CoreGraphics

public final class EventLayoutAttributes {
  public let descriptor: EventDescriptor
  public var frame = CGRect.zero
  public var intersections: [Int] = []

  public init(_ descriptor: EventDescriptor) {
    self.descriptor = descriptor
  }
}
