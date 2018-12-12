//
//  SqlStack.swift
//  FMDBDemo
//
//  Created by Ryan on 2018/11/23.
//  Copyright © 2018 Ryan. All rights reserved.
//
//  pod 'FMDB'

import Foundation
import FMDB

// MARK: - 模型协议

enum DbProperty {
    case text(key: String, value: String?)
    case integer(key: String, value: Int?)
    case real(key: String, value: CGFloat?)
    case blob(key: String, value: Data?)
    
    var type: String {
        switch self {
        case .text:
            return "TEXT"
        case .integer:
            return "INTEGER"
        case .real:
            return "REAL"
        case .blob:
            return "BLOB"
        }
    }
    
    var key: String {
        switch self {
        case let .text(key, _),
             let .integer(key, _),
             let .real(key, _),
             let .blob(key, _):
            return key
        }
    }
    
    var value: Any {
        switch self {
        case let .text(_, value):
            return value ?? NSNull()
        case let .integer(_, value):
            return value ?? NSNull()
        case let .real(_, value):
            return value ?? NSNull()
        case let .blob(_, value):
            return value ?? NSNull()
        }
    }
}

protocol DbStructProtocol {
    /// 写入数据库的对象数据
    var propertys: [DbProperty] { get }
    
    /// 从数据库读取数据转对象模型
    static func create(with resultSet: FMResultSet) -> Any?
    
    /// 数据库建表升级增加列
    static var classPropertys: [DbProperty] { get }
    
    /// 数据库升级删除多余列
    static var deletePropertys: [DbProperty] { get }
}


// MARK: - 条件枚举

enum DbCondition {
    // 与
    case and([DbFilter])
    // 或
    case or([DbFilter])
    
    var joinStream: String {
        var relationKey = ""
        var filters: [DbFilter]
        
        switch self {
        case let .and(dbFilters):
            relationKey = "and"
            filters = dbFilters
            
        case let .or(dbFilters):
            relationKey = "or"
            filters = dbFilters
        }
        
        guard filters.count > 0 else { return "" }
        
        // 排序
        let sortedFilters = filters.sorted(by: { $0.priority > $1.priority })
        
        // 分离 可拼接/不可拼接 过滤条件
        let independentFilters = sortedFilters.filter({ $0.independent })
        let unIndependentFilters = sortedFilters.filter({ !$0.independent })
        
        return " where"
            + unIndependentFilters.map({ $0.stream }).joined(separator: relationKey)
            + independentFilters.map({ $0.stream }).joined(separator: "")
    }
    
}

enum DbFilter {
    // 取前指定数量
    case limit(count: Int)
    // 取指定范围数量
    case scopeLimit(start: Int, length: Int)
    // 指定属性降序
    case sortDesc(key: String)
    // 指定属性升序
    case sortAsc(key: String)
    // 等于
    case equal(key: String, value: Any)
    // 不等于
    case notEqual(key: String, value: Any)
    // 大于
    case bigger(key: String, value: Any)
    // 小于
    case smaller(key: String, value: Any)
    // 大于等于
    case biggerEqual(key: String, value: Any)
    // 小于等于
    case smallerEqual(key: String, value: Any)
    // 开头包含
    case likePre(key: String, value: String)
    // 结尾包含
    case likeSuffix(key: String, value: String)
    // 中间包含
    case likeMid(key: String, value: String)
    // 不包含
    case unlike(key: String, value: String)
    
    var stream: String {
        switch self {
        case let .limit(count):
            return " limit \(count) "
            
        case let .scopeLimit(start, length):
            return " limit \(start), \(length) "
            
        case let .sortDesc(key):
            return " order by \(key) desc "
            
        case let .sortAsc(key):
            return " order by \(key) asc "
            
        case let .equal(key, value):
            return " \(key) = \(value) "
            
        case let .notEqual(key, value):
            return " \(key) <> \(value) "
            
        case let .bigger(key, value):
            return " \(key) > \(value) "
            
        case let .smaller(key, value):
            return " \(key) < \(value) "
            
        case let .biggerEqual(key, value):
            return " \(key) >= \(value) "
            
        case let .smallerEqual(key, value):
            return " \(key) <= \(value) "
            
        case let .likeSuffix(key, value):
            return " \(key) like '%\(value)' "
            
        case let .likePre(key, value):
            return " \(key) like '\(value)%' "
            
        case let .likeMid(key, value):
            return " \(key) like '%\(value)%' "
            
        case let .unlike(key, value):
            return  " \(key) not like '%\(value)%' "
        }
    }
    
    // 优先级小的排序放后面
    var priority: Int {
        switch self {
        case .limit, .scopeLimit:
            return 1
        case .sortDesc, .sortAsc:
            return 2
        default:
            return 3
        }
    }
    
    // 是否独立（不可拼接 and or 关系字符）
    var independent: Bool {
        switch self {
        case .limit, .scopeLimit, .sortDesc, .sortAsc:
            return true
        default:
            return false
        }
    }
}


// MARK: - SQL操作

class DbStack {
    
    static let share = DbStack()
    private var queues = [String : FMDatabaseQueue]()
    
    private func databasePath(with name: String) -> String {
        let compontName = "/" + name + ".sqlite"
        return NSSearchPathForDirectoriesInDomains(.documentDirectory,
                                                   .userDomainMask,
                                                   true)[0] + compontName
    }
 
    private static func dbLog(message: String?) {
        let enableLog = true
        guard enableLog, let message = message else  { return }
        print("[SQL]：" + message)
    }
}

extension DbStack {
    
    // 建
    func loadDatabase(targetClass: AnyClass) -> Bool {
        guard let theClass = targetClass as? DbStructProtocol.Type else {
            DbStack.dbLog(message: "未遵循 DbStructProtocol 协议，导致建表失败")
            return false
        }
        
        let dbname = String(describing: targetClass.self)
        let db = FMDatabase(path: databasePath(with: dbname))
        
        if db.open() {
            // sql句段
            let stream = theClass.classPropertys.map({ ", " + $0.key + " " + $0.type }).joined(separator: "")
            let sql = "create table if not exists \(dbname) (id integer primary key autoincrement" + stream + ")"
            DbStack.dbLog(message: sql)
            
            // 建表
            let successs = db.executeStatements(sql)
            
            // 添加队列
            if let queue = FMDatabaseQueue(path: databasePath(with: dbname)) {
                queues.updateValue(queue, forKey: dbname)
            }
            
            db.close()
            
            // 升级
            upgrade(targetClass: targetClass)
            
            return successs
        }
        
        return false
    }
    
    // 升级
    func upgrade(targetClass: AnyClass) {
        let dbname = String(describing: targetClass.self)
        guard let queue = queues[dbname], let theClass = targetClass as? DbStructProtocol.Type else { return }
        
        queue.inDatabase { (db) in
            if db.open() {
                // 新增列数据
                for addProperty in theClass.classPropertys {
                    if !db.columnExists(addProperty.key, inTableWithName: dbname) {
                        let sql = "alter table \(dbname) add \(addProperty.key) \(addProperty.type)"
                        let _ = db.executeUpdate(sql, withArgumentsIn: [])
                    }
                }
                // 删除多余列数据
                for deleteProperty in theClass.deletePropertys {
                    if !db.columnExists(deleteProperty.key, inTableWithName: dbname) {
                        let sql = "alter table \(dbname) drop \(deleteProperty.key) \(deleteProperty.type)"
                        let _ = db.executeUpdate(sql, withArgumentsIn: [])
                    }
                }
                db.close()
            }
        }
    }
    
    
    // 增
    func insert(object: DbStructProtocol,
                complete: ((_ success: Bool) -> Void)? = nil) {
        
        let dbname = String(describing: type(of: object).self)
        guard let queue = queues[dbname] else {
            DbStack.dbLog(message: "insert \(dbname) but database queue is not exist")
            complete?(false)
            return
        }
        
        queue.inDatabase({ (db) in
            var success = false
            
            if db.open() {
                // sql句段
                let keyStream = object.propertys.map({ $0.key }).joined(separator: ",")
                let questionStream = repeatElement("?", count: object.propertys.count).joined(separator: ",")
                let sql = "insert into \(dbname) (" + keyStream + ") values (" + questionStream + ")"
                DbStack.dbLog(message: sql)
                
                // 执行
                let values = object.propertys.map({ $0.value })
                success = db.executeUpdate(sql, withArgumentsIn: values)
                DbStack.dbLog(message: "\(values)")
                
                db.close()
            }
            
            DispatchQueue.main.async {
                complete?(success)
            }
        })
    }
    
    // 删
    func delete(with dbName: String,
                condition: DbCondition? = nil,
                complete: ((_ success: Bool) -> Void)? = nil) {
        guard let queue = queues[dbName] else {
            DbStack.dbLog(message: "delete \(dbName) but database queue is not exist")
            complete?(true)
            return
        }
        
        queue.inDatabase({ (db) in
            var success = false
            if db.open() {
                // sql句段
                let sql = "delete from \(dbName) " + (condition?.joinStream ?? "")
                
                // 执行
                do {
                    try db.executeUpdate(sql, values: nil)
                    success = true
                } catch { success = false }
                DbStack.dbLog(message: sql)
                
                db.close()
            }
            
            DispatchQueue.main.async {
                complete?(success)
            }
            
        })
    }
    
    // 查
    func select(targetClass: AnyClass,
                condition: DbCondition? = nil,
                complete: ((_ results: [Any]?) -> Void)?) {
        let dbname = String(describing: targetClass.self)
        guard let queue = queues[dbname] else {
            DbStack.dbLog(message: "select \(dbname) but database queue is not exist")
            complete?(nil)
            return
        }
        
        var targetObjects = [Any]()
        queue.inDatabase({ (db) in
            var results: FMResultSet?
            
            if db.open() {
                // sql句段
                let sql = "select * from \(dbname) " + (condition?.joinStream ?? "")
                
                // 执行
                do {
                    results = try db.executeQuery(sql, values: nil)
                } catch {}
                DbStack.dbLog(message: sql)
                
                // 处理搜索结果
                if let results = results,
                    let theClass = targetClass as? DbStructProtocol.Type {
                    while results.next() {
                        if let targetObject = theClass.create(with: results) {
                            targetObjects.append(targetObject)
                        }
                    }
                }
                
                db.close()
            }
            
            DispatchQueue.main.async {
                complete?(targetObjects)
            }
            
        })
    }
    
    // 改
    func update(object: DbStructProtocol,
                condition: DbCondition,
                complete: ((_ success: Bool) -> Void)? = nil) {
        
        let dbname = String(describing: type(of: object).self)
        guard let queue = queues[dbname] else {
            DbStack.dbLog(message: "update \(dbname) but database queue is not exist")
            complete?(false)
            return
        }
        
        queue.inDatabase({ (db) in
            var success = false
            if db.open() {
                // sql句段
                let keyStream = object.propertys.map({ $0.key + "= ?" }).joined(separator: ",")
                let sql = "update \(dbname) set " + keyStream + condition.joinStream
                DbStack.dbLog(message: sql)
                
                // 执行
                let values = object.propertys.map({ $0.value })
                success = db.executeUpdate(sql, withArgumentsIn: values)
                DbStack.dbLog(message: "\(values)")
                
                db.close()
            }
            
            DispatchQueue.main.async {
                complete?(success)
            }
        })
        
    }
    
}




