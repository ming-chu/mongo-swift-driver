import Foundation
@testable import MongoSwift
import Nimble
import XCTest

final class Document_SequenceTests: XCTestCase {
    static var allTests: [(String, (Document_SequenceTests) -> () throws -> Void)] {
        return [
            ("testIterator", testIterator),
            ("testMapFilter", testMapFilter),
            ("testDropFirst", testDropFirst),
            ("testDropLast", testDropLast),
            ("testDropPredicate", testDropPredicate),
            ("testPrefixLength", testPrefixLength),
            ("testPrefixPredicate", testPrefixPredicate),
            ("testSuffix", testSuffix),
            ("testSplit", testSplit)
        ]
    }

    func testIterator() {
        let doc: Document = [
            "string": "test string",
            "true": true,
            "false": false,
            "int": 25,
            "int32": Int32(5),
            "double": Double(15),
            "decimal128": Decimal128("1.2E+10"),
            "minkey": MinKey(),
            "maxkey": MaxKey(),
            "date": Date(timeIntervalSince1970: 5000),
            "timestamp": Timestamp(timestamp: 5, inc: 10)
        ]

        for (_, _) in doc { }
    }

    func testMapFilter() throws {
        let doc1: Document = ["a": 1, "b": nil, "c": 3, "d": 4, "e": nil]
        expect(doc1.mapValues { $0 ?? 1 }).to(equal(["a": 1, "b": 1, "c": 3, "d": 4, "e": 1]))
        let output1 = doc1.mapValues { val in
            if let int = val as? Int { return int + 1 }
            return val
        }
        expect(output1).to(equal(["a": 2, "b": nil, "c": 4, "d": 5, "e": nil]))
        expect(doc1.filter { $0.value != nil }).to(equal(["a": 1, "c": 3, "d": 4]))

        let doc2: Document = ["a": 1, "b": "hello", "c": [1, 2] as [Int]]
        expect(doc2.filter { $0.value is String }).to(equal(["b": "hello"]))
        let output2 = doc2.mapValues { val in
            switch val {
            case let val as Int:
                return val + 1
            case let val as String:
                return val + " there"
            case let val as [Int]:
                return val.reduce(0, +)
            default:
                return val
            }
        }
        expect(output2).to(equal(["a": 2, "b": "hello there", "c": 3]))
    }

    // shared docs for subsequence tests
    let emptyDoc = Document()
    let smallDoc: Document = ["x": 1]
    let doc: Document = ["a": 1, "b": "hi", "c": [1, 2] as [Int], "d": false, "e": nil, "f": MinKey(), "g": 10]

    // shared predicates for subsequence tests
    func isInt(_ pair: Document.KeyValuePair) -> Bool { return pair.value is Int }
    func isNotNil(_ pair: Document.KeyValuePair) -> Bool { return pair.value != nil }
    func is10(_ pair: Document.KeyValuePair) -> Bool {
        if let int = pair.value as? Int { return int == 10 } else { return false }
    }
    func isNot10(_ pair: Document.KeyValuePair) -> Bool { return !is10(pair) }

    func testDropFirst() throws {
        expect(self.emptyDoc.dropFirst(0)).to(equal([:]))
        expect(self.emptyDoc.dropFirst(1)).to(equal([:]))

        expect(self.smallDoc.dropFirst(0)).to(equal(smallDoc))
        expect(self.smallDoc.dropFirst()).to(equal([:]))
        expect(self.smallDoc.dropFirst(2)).to(equal([:]))

        expect(self.doc.dropFirst(0)).to(equal(doc))
        expect(self.doc.dropFirst()).to(equal(["b": "hi", "c": [1, 2] as [Int], "d": false, "e": nil, "f": MinKey(), "g": 10]))
        expect(self.doc.dropFirst(4)).to(equal(["e": nil, "f": MinKey(), "g": 10]))
        expect(self.doc.dropFirst(7)).to(equal([:]))
        expect(self.doc.dropFirst(8)).to(equal([:]))
    }

    func testDropLast() throws {
        expect(self.emptyDoc.dropLast(0)).to(equal([:]))
        expect(self.emptyDoc.dropLast(1)).to(equal([:]))

        expect(self.smallDoc.dropLast(0)).to(equal(smallDoc))
        expect(self.smallDoc.dropLast()).to(equal([:]))
        expect(self.smallDoc.dropLast(2)).to(equal([:]))

        expect(self.doc.dropLast(0)).to(equal(doc))
        expect(self.doc.dropLast()).to(equal(["a": 1, "b": "hi", "c": [1, 2] as [Int], "d": false, "e": nil, "f": MinKey()]))
        expect(self.doc.dropLast(4)).to(equal(["a": 1, "b": "hi", "c": [1, 2] as [Int]]))
        expect(self.doc.dropLast(7)).to(equal([:]))
        expect(self.doc.dropLast(8)).to(equal([:]))
    }

    func testDropPredicate() throws {
        expect(self.emptyDoc.drop(while: self.isInt)).to(equal([:]))
        expect(self.smallDoc.drop(while: self.isInt)).to(equal([:]))
        expect(self.doc.drop(while: self.isInt)).to(equal(["b": "hi", "c": [1, 2] as [Int], "d": false, "e": nil, "f": MinKey(), "g": 10]))

        expect(self.emptyDoc.drop(while: self.isNotNil)).to(equal([:]))
        expect(self.smallDoc.drop(while: self.isNotNil)).to(equal([:]))
        expect(self.doc.drop(while: self.isNotNil)).to(equal(["e": nil, "f": MinKey(), "g": 10]))

        expect(self.emptyDoc.drop(while: self.isNot10)).to(equal([:]))
        expect(self.smallDoc.drop(while: self.isNot10)).to(equal([:]))
        expect(self.doc.drop(while: self.isNot10)).to(equal(["g": 10]))

        expect(self.emptyDoc.drop(while: self.is10)).to(equal([:]))
        expect(self.smallDoc.drop(while: self.is10)).to(equal(smallDoc))
        expect(self.doc.drop(while: self.is10)).to(equal(doc))
    }

    func testPrefixLength() throws {
        expect(self.emptyDoc.prefix(0)).to(equal([:]))
        expect(self.emptyDoc.prefix(1)).to(equal([:]))

        expect(self.smallDoc.prefix(0)).to(equal([:]))
        expect(self.smallDoc.prefix(1)).to(equal(smallDoc))
        expect(self.smallDoc.prefix(2)).to(equal(smallDoc))

        expect(self.doc.prefix(0)).to(equal([:]))
        expect(self.doc.prefix(1)).to(equal(["a": 1]))
        expect(self.doc.prefix(2)).to(equal(["a": 1, "b": "hi"]))
        expect(self.doc.prefix(4)).to(equal(["a": 1, "b": "hi", "c": [1, 2] as [Int], "d": false]))
        expect(self.doc.prefix(7)).to(equal(doc))
        expect(self.doc.prefix(8)).to(equal(doc))
    }

    func testPrefixPredicate() throws {
        expect(self.emptyDoc.prefix(while: self.isInt)).to(equal([:]))
        expect(self.smallDoc.prefix(while: self.isInt)).to(equal(smallDoc))
        expect(self.doc.prefix(while: self.isInt)).to(equal(["a": 1]))

        expect(self.emptyDoc.prefix(while: self.isNotNil)).to(equal([:]))
        expect(self.smallDoc.prefix(while: self.isNotNil)).to(equal(smallDoc))
        expect(self.doc.prefix(while: self.isNotNil)).to(equal(["a": 1, "b": "hi", "c": [1, 2] as [Int], "d": false]))

        expect(self.emptyDoc.prefix(while: self.isNot10)).to(equal([:]))
        expect(self.smallDoc.prefix(while: self.isNot10)).to(equal(smallDoc))
        expect(self.doc.prefix(while: self.isNot10)).to(equal(["a": 1, "b": "hi", "c": [1, 2] as [Int], "d": false, "e": nil, "f": MinKey()]))

        expect(self.emptyDoc.prefix(while: self.is10)).to(equal([:]))
        expect(self.smallDoc.prefix(while: self.is10)).to(equal([:]))
        expect(self.doc.prefix(while: self.is10)).to(equal([:]))
    }

    func testSuffix() throws {
        expect(self.emptyDoc.suffix(0)).to(equal([:]))
        expect(self.emptyDoc.suffix(1)).to(equal([:]))
        expect(self.emptyDoc.suffix(5)).to(equal([:]))

        expect(self.smallDoc.suffix(0)).to(equal([:]))
        expect(self.smallDoc.suffix(1)).to(equal(smallDoc))
        expect(self.smallDoc.suffix(2)).to(equal(smallDoc))
        expect(self.smallDoc.suffix(5)).to(equal(smallDoc))

        expect(self.doc.suffix(0)).to(equal([]))
        expect(self.doc.suffix(1)).to(equal(["g": 10]))
        expect(self.doc.suffix(2)).to(equal(["f": MinKey(), "g": 10]))
        expect(self.doc.suffix(4)).to(equal(["d": false, "e": nil, "f": MinKey(), "g": 10]))
        expect(self.doc.suffix(7)).to(equal(doc))
        expect(self.doc.suffix(8)).to(equal(doc))
    }

    func testSplit() throws {
        expect(self.emptyDoc.split(whereSeparator: self.isInt)).to(equal([]))
        expect(self.smallDoc.split(whereSeparator: self.isInt)).to(equal([]))
        expect(self.doc.split(whereSeparator: self.isInt)).to(equal([["b": "hi", "c": [1, 2] as [Int], "d": false, "e": nil, "f": MinKey()]]))

        expect(self.emptyDoc.split(omittingEmptySubsequences: false, whereSeparator: self.isInt)).to(equal([[:]]))
        expect(self.smallDoc.split(omittingEmptySubsequences: false, whereSeparator: self.isInt)).to(equal([[:], [:]]))
        expect(self.doc.split(omittingEmptySubsequences: false, whereSeparator: self.isInt)).to(equal([[:], ["b": "hi", "c": [1, 2] as [Int], "d": false, "e": nil, "f": MinKey()], [:]]))

        expect(self.doc.split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: self.isInt))
            .to(equal([[:], ["b": "hi", "c": [1, 2] as [Int], "d": false, "e": nil, "f": MinKey(), "g": 10]]))

    }
}