//
//  ViewController.swift
//  DbStack
//
//  Created by Ryan on 2018/12/12.
//  Copyright © 2018 Ryan. All rights reserved.
//

import UIKit
import FMDB

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let _ = DbStack.share.loadDatabase(targetClass: Person.self)
    }

    @IBAction func addAction(_ sender: Any) {
        let person = Person()
        person.name = "李明六"
        person.age = Int(arc4random() % 50)
        person.address = "湖北"
        person.phone = "999"
        
        DbStack.share.insert(object: person) { (success) in
            print(success ? "保存成功" : "保存失败")
        }
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        let filter1 = DbFilter.biggerEqual(key: "age", value: 49)
        DbStack.share.delete(with: String(describing: Person.self), condition: DbCondition.or([filter1]))
    }
    
    @IBAction func selectAction(_ sender: Any) {
//        let f0 = DbFilter.limit(count: 5)
//        let f1 = DbFilter.biggerEqual(key: "age", value: 40)
//        let f2 = DbFilter.sortAsc(key: "age")
//        let f3 = DbFilter.smaller(key: "age", value: 60)
//        let f4 = DbFilter.likeSuffix(key: "name", value: "三")
//        let f5 = DbFilter.likeMid(key: "name", value: "明")
        let f6 = DbFilter.likePre(key: "name", value: "李")
//        let f7 = DbFilter.unlike(key: "name", value: "李")
        
        DbStack.share.select(targetClass: Person.self,
                             condition: DbCondition.or([f6])) { (results) in
                                if let results = results {
                                    for obj in results {
                                        if let person = obj as? Person {
                                            print("---------")
                                            print(person.name)
                                            print(person.age)
                                            print(person.address)
                                            print(person.phone)
                                        }
                                    }
                                }
        }
        
//        DbStack.share.select(targetClass: Person.self) { (results) in
//            if let results = results {
//                for obj in results {
//                    if let person = obj as? Person {
//                        print("---------")
//                        print(person.name)
//                        print(person.age)
//                        print(person.address)
//                    }
//                }
//            }
//        }
    }
    
    @IBAction func updateAction(_ sender: Any) {
        let person = Person()
        person.name = "张四"
        person.age = 100
        person.address = "广州"
        
        let filter1 = DbFilter.equal(key: "name", value: "张四")
        DbStack.share.update(object: person, condition: DbCondition.and([filter1]))
    }
}


class Person {
    var name: String? = "张四"
    var age: Int? = 26
    var address: String? = "广州"
    
    var phone: String? = "321"
}

extension Person: DbStructProtocol {
    
    var propertys: [DbProperty] {
        return [DbProperty.text(key: "name", value: name),
                DbProperty.integer(key: "age", value: age),
                DbProperty.text(key: "address", value: address),
                DbProperty.text(key: "phone", value: phone)]
    }
    
    static var classPropertys: [DbProperty] {
        return [DbProperty.text(key: "name", value: nil),
                DbProperty.integer(key: "age", value: nil),
                DbProperty.text(key: "address", value: nil),
                DbProperty.text(key: "phone", value: nil)]
    }
    
    static var deletePropertys: [DbProperty] {
        return []
    }
    
    static func create(with resultSet: FMResultSet) -> Any? {
        let person = Person()
        person.name = resultSet.string(forColumn: "name")
        person.age = Int(resultSet.int(forColumn: "age"))
        person.address = resultSet.string(forColumn: "address")
        person.phone = resultSet.string(forColumn: "phone")
        return person
    }
}
