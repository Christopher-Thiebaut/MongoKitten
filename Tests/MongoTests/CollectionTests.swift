//
//  CollectionTests.swift
//  MongoKitten
//
//  Created by Joannis Orlandos on 23/03/16.
//  Copyright © 2016 PlanTeam. All rights reserved.
//

import XCTest
import MongoKitten

class CollectionTests: XCTestCase {
    static var allTests: [(String, CollectionTests -> () throws -> Void)] {
        return [
                   ("testDistinct", testDistinct),
                   ("testFind", testFind),
                   ("testUpdate", testUpdate),
                   ("testDelete", testDelete),
        ]
    }
    
    override func setUp() {
        super.setUp()
        
        do {
            try TestManager.connect()
        } catch {
            
        }
        
        try! TestManager.dropAllTestingCollections()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testDistinct() {
        try! TestManager.fillCollectionWithSampleUsers()
        let distinct = try! TestManager.testCollection.distinct("gender")!
        
        XCTAssertEqual(distinct.count, 2)
    }
    
    func testFind() {
        let base = *["username": "bob", "age": 25, "kittens": 6, "dogs": 0, "beers": 90]
        
        var inserts: [Document]
        
        var brokenUsername = base
        var brokenAge = base
        var brokenKittens = base
        var brokenKittens2 = base
        var brokenDogs = base
        var brokenBeers = base
        
        brokenUsername["username"] = "harrie"
        brokenAge["age"] = 24
        brokenKittens["kittens"] = 3
        brokenKittens2["kittens"] = 1
        brokenDogs["dogs"] = 2
        brokenBeers["beers"] = "broken"
        
        inserts = [base, brokenUsername, brokenUsername, brokenAge, brokenDogs, brokenKittens, brokenKittens2, brokenBeers, base]
        
        _ = try! TestManager.testCollection.insert(inserts)
        
        let query: Query = ("username" == "henk" || "username" == "bob") && "age" > 24 && "kittens" >= 2 && "kittens" != 3 && "dogs" <= 1 && "beers" < 100
        
        let response = Array(try! TestManager.testCollection.find(matching: query))
        
        let response2 = try! TestManager.testCollection.findOne(matching: query)!
        
        XCTAssertEqual(response.count, 2)
        
        XCTAssertEqual(response.first, response2)
    }
    
    func testUpdate() {
        try! TestManager.fillCollectionWithSampleUsers()
        
        let males = try! TestManager.testCollection.count(matching: "gender" == "Male")
        
        let females = try! TestManager.testCollection.count(matching: "gender" == "Female")
        
        try! TestManager.testCollection.update(matching: "gender" == "Male", to: ["$set": *["gender": "Female"]])
        
        let males2 = try! TestManager.testCollection.count(matching: "gender" == "Male")
        
        let females2 = try! TestManager.testCollection.count(matching: "gender" == "Female")
        
        XCTAssertEqual(males2, 0)
        XCTAssertEqual(females2, males + females)
    }
    
    func testDelete() {
        try! TestManager.fillCollectionWithSampleUsers()
        
        try! TestManager.testCollection.remove(matching: "gender" == "Male")
        
        let insertedAmount = try! TestManager.testCollection.count(matching: "gender" == "male")
        
        XCTAssertEqual(insertedAmount, 0)
    }
}
