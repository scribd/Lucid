//
//  CoreDataConversion.swift
//  Lucid
//
//  Created by Théophane Rupin on 12/21/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation
import AVFoundation
import CoreData

// MARK: - Coders

private enum Coders {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.set(context: .coreDataRelationship)
        return encoder
    }()
    
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.set(context: .coreDataRelationship)
        return decoder
    }()
}

// MARK: - CoreDataConversionError

public enum CoreDataConversionError: Error {
    case corruptedProperty(name: String?)
}

// MARK: - CoreDataPrimitiveValue

public protocol CoreDataPrimitiveValue {}
extension String: CoreDataPrimitiveValue {}
extension Int: CoreDataPrimitiveValue {}
extension Float: CoreDataPrimitiveValue {}
extension Double: CoreDataPrimitiveValue {}

// MARK: - NSManagedObject Utils

public extension NSManagedObject {
    
    func setProperty<T>(_ name: String, value: T?) {
        willChangeValue(forKey: name)
        defer { didChangeValue(forKey: name) }
        
        guard let value = value else {
            setPrimitiveValue(nil, forKey: name)
            return
        }
        setPrimitiveValue(value, forKey: name)
    }
    
    func propertyValue<T>(for name: String) -> T? where T: CoreDataPrimitiveValue {
        willAccessValue(forKey: name)
        defer { didAccessValue(forKey: name) }
        return (primitiveValue(forKey: name) as? T)
    }
    
    func propertyValue<T>(for name: String) throws -> T where T: CoreDataPrimitiveValue {
        guard let value: T = propertyValue(for: name) else {
            throw CoreDataConversionError.corruptedProperty(name: name)
        }
        return value
    }
}

// MARK: - JSONDecoder Utils

public extension Data {
    func decodedValue<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try Coders.decoder.decode(T.self, from: self)
    }
    
    func decodedValue<T>(_ type: T.Type) -> T? where T: Decodable {
        do {
            return try decodedValue(type) as T
        } catch {
            Logger.log(.error, "\(Data.self): Could not decode \(T.self): \(error)", assert: true)
            return nil
        }
    }
}

public extension Optional where Wrapped == Data {
    func decodedValue<T>(_ type: T.Type, propertyName: String) throws -> T where T: Decodable {
        guard let value = self?.decodedValue(type) else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return value
    }
}

// MARK: - Array

public extension Sequence where Element: Encodable {

    func coreDataValue() throws -> Data {
        return try Coders.encoder.encode(Array(self))
    }
    
    func coreDataValue() -> Data? {
        do {
            return try coreDataValue() as Data
        } catch {
            Logger.log(.error, "\(Self.self): Could not encode: \(error).", assert: true)
            return nil
        }
    }
}

public extension Sequence where Element: CoreDataIdentifier {
    func coreDataValue() -> Data? {
        return map { $0.value }.coreDataValue()
    }
}

public extension Optional where Wrapped: Sequence, Wrapped.Element: CoreDataIdentifier {
    func coreDataValue() -> Data? {
        return self?.coreDataValue()
    }
}

// MARK: - CoreDataIdentifier

public extension CoreDataIdentifier where LocalValueType == Int {
    func localCoreDataValue() -> Int64? {
        return value.localValue.flatMap { Int64($0) }
    }
}

public extension Optional where Wrapped: CoreDataIdentifier, Wrapped.LocalValueType == Int {
    func localCoreDataValue() -> Int64? {
        return self?.localCoreDataValue()
    }
}

public extension CoreDataIdentifier where LocalValueType == String {
    func localCoreDataValue() -> String? {
        return value.localValue
    }
}

public extension Optional where Wrapped: CoreDataIdentifier, Wrapped.LocalValueType == String {
    func localCoreDataValue() -> String? {
        return self?.localCoreDataValue()
    }
}

public extension CoreDataIdentifier where RemoteValueType == Int {
    func remoteCoreDataValue() -> Int64? {
        return value.remoteValue.flatMap { Int64($0) }
    }
}

public extension Optional where Wrapped: CoreDataIdentifier, Wrapped.RemoteValueType == Int {
    func remoteCoreDataValue() -> Int64? {
        return self?.remoteCoreDataValue()
    }
}

public extension CoreDataIdentifier where RemoteValueType == String {
    func remoteCoreDataValue() -> String? {
        return value.remoteValue
    }
}

public extension Optional where Wrapped: CoreDataIdentifier, Wrapped.RemoteValueType == String {
    func remoteCoreDataValue() -> String? {
        return self?.remoteCoreDataValue()
    }
}

// MARK: - IdentifierValueType

public extension NSManagedObject {
    
    func identifierValueType<I>(_ identifierType: I.Type, propertyName: String? = nil) throws -> IdentifierValueType<I.LocalValueType, I.RemoteValueType> where I: CoreDataIdentifier {
        return try IdentifierValueType(
            remoteValue: propertyValue(for: propertyName ?? I.remotePredicateString),
            localValue: propertyValue(for: propertyName.flatMap { "_\($0)" } ?? I.localPredicateString),
            propertyName: propertyName
        )
    }
    
    func identifierValueType<I>(_ identifierType: I.Type, identifierTypeID: String?, propertyName: String? = nil) throws -> I where I: CoreDataIdentifier {
        return I(value: try identifierValueType(I.self, propertyName: propertyName),
                 identifierTypeID: identifierTypeID,
                 remoteSynchronizationState: nil)
    }

    func identifierValueType<I>(_ identifierType: I.Type, identifierTypeID: String?, propertyName: String? = nil, remoteSynchronizationState: RemoteSynchronizationState? = nil) throws -> I where I: CoreDataIdentifier, I: RemoteIdentifier {
        return I(value: try identifierValueType(I.self, propertyName: propertyName),
                 identifierTypeID: identifierTypeID,
                 remoteSynchronizationState: remoteSynchronizationState)
    }
    
    func identifierValueType<I>(_ identifierType: I.Type, identifierTypeID: String? = nil, propertyName: String? = nil) -> I? where I: CoreDataIdentifier {
        do {
            return try identifierValueType(I.self, identifierTypeID: identifierTypeID, propertyName: propertyName) as I
        } catch {
            return nil
        }
    }
}

private extension IdentifierValueType {
    init(remoteValue: RemoteValueType?, localValue: LocalValueType?, propertyName: String?) throws {
        switch (remoteValue, localValue) {
        case (.some(let remoteValue), let localValue):
            self = .remote(remoteValue, localValue)
        case (nil, .some(let localValue)):
            self = .local(localValue)
        default:
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
    }
}

public extension Data {
    func identifierValueTypeArrayValue<I>(_ identifierType: I.Type) -> AnySequence<IdentifierValueType<I.LocalValueType, I.RemoteValueType>>? where I: CoreDataIdentifier {
        return decodedValue([IdentifierValueType<I.LocalValueType, I.RemoteValueType>].self)?.lazy.any
    }
    
    func identifierValueTypeArrayValue<I>(_ identifierType: I.Type) throws -> AnySequence<IdentifierValueType<I.LocalValueType, I.RemoteValueType>> where I: CoreDataIdentifier {
        return try decodedValue([IdentifierValueType<I.LocalValueType, I.RemoteValueType>].self).lazy.any
    }
}

// MARK: - String

public extension String {
    func coreDataValue() -> String {
        return self
    }
    
    func stringValue() -> String {
        return self
    }
}

public extension Optional where Wrapped == String {
    func coreDataValue() -> String? {
        return self?.coreDataValue()
    }
    
    func stringValue() -> String? {
        return self
    }
    
    func stringValue(propertyName: String) throws -> String {
        guard let value = self else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return value
    }
}

public extension Data {
    func stringArrayValue() -> AnySequence<String>? {
        return decodedValue([String].self)?.lazy.any
    }

    func stringArrayValue() throws -> AnySequence<String> {
        return try decodedValue([String].self).lazy.any
    }
}

public extension Optional where Wrapped == Data {
    func stringArrayValue(propertyName: String) throws -> AnySequence<String> {
        guard let value = self?.stringArrayValue() else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return value
    }
}

public extension NSManagedObject {
    func stringValue(propertyName: String) -> String? {
        return propertyValue(for: propertyName)
    }
}

// MARK: - Int

public extension Int {
    func coreDataValue() -> Int64 {
        return Int64(self)
    }
}

public extension Optional where Wrapped == Int {
    func coreDataValue() -> Int64? {
        return self?.coreDataValue()
    }
}

public extension Optional where Wrapped == Int? {
    func intValue() -> Int64? {
        return self??.coreDataValue()
    }
}

public extension Sequence where Element == Int {
    func coreDataValue() -> Data {
        var value = self
        return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
    }
}

public extension Int64 {
    func intValue() -> Int {
        return self < Int.max ? Int(self) : 0
    }
}

public extension Optional where Wrapped == Int64 {
    func intValue() -> Int? {
        return self?.intValue()
    }
}

public extension Optional where Wrapped == Int64? {
    func intValue() -> Int? {
        return self?.intValue()
    }
}

public extension NSManagedObject {
    func intValue(propertyName: String) -> Int? {
        return propertyValue(for: propertyName)
    }
    
    func intValue(propertyName: String) throws -> Int {
        return try propertyValue(for: propertyName)
    }
}

public extension Data {
    func intArrayValue() -> [Int]? {
        return decodedValue([Int].self)
    }
    
    func intArrayValue() throws -> [Int] {
        return try decodedValue([Int].self)
    }
}

// MARK: - Float

public extension Float {
    func coreDataValue() -> Float {
        return self
    }
    
    func floatValue() -> Float {
        return self
    }
}

public extension Optional where Wrapped == Float {
    func coreDataValue() -> Float? {
        return self?.coreDataValue()
    }
    
    func floatValue() -> Float? {
        return self
    }
}

public extension NSManagedObject {
    func floatValue(propertyName: String) -> Float? {
        return propertyValue(for: propertyName)
    }
    
    func floatValue(propertyName: String) throws -> Float {
        return try propertyValue(for: propertyName)
    }
}

// MARK: - Double

public extension Double {
    func coreDataValue() -> Double {
        return self
    }
    
    func doubleValue() -> Double {
        return self
    }
}

public extension Optional where Wrapped == Double {
    func coreDataValue() -> Double? {
        return self?.coreDataValue()
    }
    
    func doubleValue() -> Double? {
        return self
    }
}

public extension NSManagedObject {
    func doubleValue(propertyName: String) -> Double? {
        return propertyValue(for: propertyName)
    }
    
    func doubleValue(propertyName: String) throws -> Double {
        return try propertyValue(for: propertyName)
    }
}

// MARK: - Date

public extension Date {
    func coreDataValue() -> Date {
        return self
    }
}

public extension Optional where Wrapped == Date {
    func coreDataValue() -> Date? {
        return self?.coreDataValue()
    }
}

public extension Date {
    func dateValue() -> Date {
        return self
    }
}

public extension Optional where Wrapped == Date {
    func dateValue() -> Date? {
        return self?.dateValue()
    }
    
    func dateValue(propertyName: String) throws -> Date {
        guard let date = self else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return date
    }
}

// MARK: - Bool

public extension Bool {
    func coreDataValue() -> Int64 {
        return self ? 1 : 0
    }
}

public extension Optional where Wrapped == Bool {
    func coreDataValue() -> Int64? {
        return self?.coreDataValue()
    }
}

public extension Int64 {
    func boolValue() -> Bool {
        return self == 0 ? false : true
    }
    
    func boolValue() -> FailableValue<Bool> {
        return .value(boolValue())
    }
}

public extension Optional where Wrapped == Int64 {
    func boolValue() -> Bool? {
        return self?.boolValue()
    }
}

public extension NSManagedObject {
    func boolValue(propertyName: String) -> Bool? {
        return intValue(propertyName: propertyName).flatMap { $0 == 0 ? false : true }
    }
    
    func boolValue(propertyName: String) throws -> Bool {
        guard let value: Bool = boolValue(propertyName: propertyName) else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return value
    }
}

// MARK: - Color

public extension Color {
    func coreDataValue() -> String {
        return hex
    }
}

public extension Optional where Wrapped == Color {
    func coreDataValue() -> String? {
        return self?.coreDataValue()
    }
}

public extension String {
    func colorValue() -> Color {
        return Color(hex: self)
    }
}

public extension Optional where Wrapped == String {
    func colorValue() -> Color? {
        return self?.colorValue()
    }
    
    func colorValue(propertyName: String) throws -> Color {
        guard let value = self?.colorValue() else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return value
    }
}

// MARK: - Time

public extension Time {
    func coreDataValue() -> Double {
        return value.seconds
    }
}

public extension Optional where Wrapped == Time {
    func coreDataValue() -> Double? {
        return self?.coreDataValue()
    }
}

public extension Double {
    func millisecondsValue() -> Milliseconds {
        return Milliseconds(seconds: self / 1000, preferredTimescale: 1000)
    }
    
    func secondsValue() -> Seconds {
        return Seconds(seconds: self, preferredTimescale: 1000)
    }
}

public extension NSManagedObject {
    func timeValue(propertyName: String) -> Time? {
        return doubleValue(propertyName: propertyName).flatMap { Time(seconds: $0) }
    }
    
    func timeValue(propertyName: String) throws -> Time {
        guard let value: Time = timeValue(propertyName: propertyName) else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return value
    }
}

// MARK: - RawRepresentable

public extension RawRepresentable {
    func coreDataValue() -> RawValue {
        return rawValue
    }
}

public extension Optional where Wrapped: RawRepresentable {
    func coreDataValue() -> Wrapped.RawValue? {
        return self?.rawValue
    }
}

public extension RawRepresentable where RawValue == Int {
    func coreDataValue() -> Int64 {
        return Int64(rawValue)
    }
}

public extension Sequence where Element: RawRepresentable, Element.RawValue == Int {
    func coreDataValue() -> Data? {
        return lazy.map { $0.rawValue }.coreDataValue()
    }
}

public extension Optional where Wrapped: Sequence, Wrapped.Element: RawRepresentable, Wrapped.Element.RawValue == Int {
    func coreDataValue() -> Data? {
        return self?.coreDataValue()
    }
}

// MARK: - URL

public extension URL {
    func coreDataValue() -> String {
        return absoluteString
    }
}

public extension Optional where Wrapped == URL {
    func coreDataValue() -> String? {
        return self?.absoluteString
    }
}

public extension String {
    func urlValue() -> URL? {
        return URL(string: self)
    }
}

public extension Optional where Wrapped == String {
    func urlValue() -> URL? {
        return self?.urlValue()
    }

    func urlValue(propertyName: String) throws -> URL {
        guard let value = self?.urlValue() else {
            throw CoreDataConversionError.corruptedProperty(name: propertyName)
        }
        return value
    }

    func urlValue(propertyName: String) throws -> URL? {
        return urlValue()
    }
}

// MARK: - Extra

public extension Extra {

    init(value: T?, requested: Bool) {
        if let value = value, requested {
            self = .requested(value)
        } else {
            if value == nil, requested {
                Logger.log(.debug, "\(Extra.self): We appear to be storing nil for a requested value of a non-optional extra. Check the API Object to make sure the description is correct.", assert: true)
            }
            self = .unrequested
        }
    }

    var coreDataFlagValue: Bool {
        switch self {
        case .requested:
            return true
        case .unrequested:
            return false
        }
    }
}

// MARK: - RemoteSynchronizationState

public extension String {
    
    var synchronizationStateValue: RemoteSynchronizationState? {
        return RemoteSynchronizationState(rawValue: self)
    }
}
