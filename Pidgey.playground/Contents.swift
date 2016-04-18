//: Playground - noun: a place where people can play

import UIKit
import Foundation
import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

var str = "Hello, playground"
let requestBin = "http://requestb.in/19ud9up1"


do {
    let request = try Pidgey.PUT(requestBin, params: ["ha h":["a h","ah"]], queryParams: ["oh o":"h o"])
    request.requestSerializationMode = .HTTP
    request.resume({ (response: PidgeyResponse?, error: NSError?) in
        print(response?.text)
    })
    
    let request2 = try Pidgey.OPTIONS(requestBin, queryParams: [:])
    request2.setAuthentication(username: "postman", password: "password")
    request2.requestSerializationMode = .HTTP
    request2.resume({ (response: PidgeyResponse?, error: NSError?) in
        print(response?.headers)
        print(error)
    })
    
    Pidgey.cancelAllRequests()
}
catch{
    print("errorrr!!!!")
}

