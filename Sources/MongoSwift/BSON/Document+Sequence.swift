import Foundation
import libmongoc

/// An extension of `Document` to make it conform to the `Sequence` protocol.
/// This allows you to iterate through the (key, value) pairs, for example:
/// ```
/// let doc: Document = ["a": 1, "b": 2]
/// for (key, value) in doc {
///     ...
/// }
/// ```
extension Document: Sequence {
    /// Returns a `DocumentIterator` over the values in this `Document`. 
    public func makeIterator() -> DocumentIterator {
        guard let iter = DocumentIterator(forDocument: self) else {
            preconditionFailure("Failed to initialize an iterator over document \(self)")
        }
        return iter
    }
}

/// An iterator over the values in a `Document`. 
public class DocumentIterator: IteratorProtocol {
    /// the libbson iterator. it must be a `var` because we use it as
    /// an inout argument
    internal var iter: bson_iter_t
    /// a reference to the storage for the document we're iterating
    internal let storage: DocumentStorage

    /// Initializes a new iterator over the contents of `doc`. Returns `nil` if the key is not 
    /// found, or if an iterator cannot be created over `doc` due to an error from e.g. corrupt data.
    internal init?(forDocument doc: Document) {
        self.iter = bson_iter_t()
        self.storage = doc.storage
        if !bson_iter_init(&self.iter, doc.data) { return nil }
    }

    /// Initializes a new iterator over the contents of `doc`. Returns `nil` if an iterator cannot
    /// be created over `doc` due to an error from e.g. corrupt data, or if the key is not found.
    internal init?(forDocument doc: Document, advancedTo key: String) {
        self.iter = bson_iter_t()
        self.storage = doc.storage
        if !bson_iter_init_find(&iter, doc.data, key.cString(using: .utf8)) {
            return nil
        }
    }

    /// Advances the iterator forward one value. Returns false if there is an error moving forward
    /// or if at the end of the document. Returns true otherwise.
    private func advance() -> Bool {
        return bson_iter_next(&self.iter)
    }

    /// Returns the current key. Assumes the iterator is in a valid position.
    internal var currentKey: String {
        return String(cString: bson_iter_key(&self.iter))
    }

    /// Returns the current value. Assumes the iterator is in a valid position.
    internal var currentValue: BsonValue? {
        do {
            switch self.currentType {
            case .symbol:
                return try Symbol.asString(from: self)
            case .dbPointer:
                return try DBPointer.asDocument(from: self)
            default:
                return try DocumentIterator.BsonTypeMap[currentType]?.init(from: self)
            }
        } catch {
            preconditionFailure("Error getting current value from iterator: \(error)")
        }
    }

    /// Returns the current value's type. Assumes the iterator is in a valid position.
    internal var currentType: BsonType {
        return BsonType(rawValue: bson_iter_type(&self.iter).rawValue) ?? .invalid
    }

    /// Returns the keys from the iterator's current position to the end. The iterator
    /// will be exhausted after this property is accessed.
    internal var keys: [String] {
        var keys = [String]()
        while self.advance() { keys.append(self.currentKey) }
        return keys
    }

    /// Returns the values from the iterator's current position to the end. The iterator
    /// will be exhausted after this property is accessed.
    internal var values: [BsonValue?] {
        var values = [BsonValue?]()
        while self.advance() { values.append(self.currentValue) }
        return values
    }

    /// Returns the next value in the sequence, or `nil` if the iterator is exhausted.
    public func next() -> (key: String, value: BsonValue?)? {
        if self.advance() {
            return (self.currentKey, self.currentValue)
        }
        return nil
    }

    internal func overwriteCurrentValue(with newValue: Overwritable) throws {
        precondition(newValue.bsonType == self.currentType,
                     "Expected \(newValue) to have BSON type \(self.currentType), but has type \(newValue.bsonType)")
        try newValue.writeToCurrentPosition(of: self)
    }

    private static let BsonTypeMap: [BsonType: BsonValue.Type] = [
        .double: Double.self,
        .string: String.self,
        .document: Document.self,
        .array: [BsonValue?].self,
        .binary: Binary.self,
        .objectId: ObjectId.self,
        .boolean: Bool.self,
        .dateTime: Date.self,
        .regularExpression: RegularExpression.self,
        .dbPointer: DBPointer.self,
        .javascript: CodeWithScope.self,
        .symbol: Symbol.self,
        .javascriptWithScope: CodeWithScope.self,
        .int32: Int.self,
        .timestamp: Timestamp.self,
        .int64: Int64.self,
        .decimal128: Decimal128.self,
        .minKey: MinKey.self,
        .maxKey: MaxKey.self
    ]
}

/// A protocol indicating that a type can be overwritten in-place on a `bson_t`.
internal protocol Overwritable: BsonValue {
    /// Overwrites the value at the current position of the iterator with self.
    func writeToCurrentPosition(of iter: DocumentIterator) throws
}

extension Bool: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_bool(&iter.iter, self) }
}

extension Int: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) throws {
        if let int32 = self.int32Value {
            return int32.writeToCurrentPosition(of: iter)
        } else if let int64 = self.int64Value {
            return int64.writeToCurrentPosition(of: iter)
        }

        throw MongoError.bsonEncodeError(message: "`Int` value \(self) could not be encoded as `Int32` or `Int64`")
    }
}

extension Int32: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_int32(&iter.iter, self) }
}

extension Int64: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_int64(&iter.iter, self) }
}

extension Double: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) { bson_iter_overwrite_double(&iter.iter, self) }
}

extension Decimal128: Overwritable {
    func writeToCurrentPosition(of iter: DocumentIterator) throws {
        var encoded = try Decimal128.encode(self.data)
        bson_iter_overwrite_decimal128(&iter.iter, &encoded)
    }
}
