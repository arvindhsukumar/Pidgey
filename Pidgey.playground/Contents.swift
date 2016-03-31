//: Playground - noun: a place where people can play

import UIKit
import Foundation
import XCPlayground

XCPlaygroundPage.currentPage.needsIndefiniteExecution = true

var str = "Hello, playground"
let requestBin = "http://requestb.in/190wskz1?heh=e"


do {
    let request = try Pidgey.POST(requestBin, params: ["ha h":["a h","ah"]], queryParams: ["oh o":"h o"])
    request.requestSerializationMode = .HTTP
    request.resume({ (response: PidgeyResponse?, error: NSError?) in
        print(response?.text)
    })
    
    let request2 = try Pidgey.GET(requestBin, queryParams: [:])
    request2.setAuthentication(username: "postman", password: "password")
    request2.requestSerializationMode = .HTTP
    request2.resume({ (response: PidgeyResponse?, error: NSError?) in
        print(response?.text)
    })
}
catch{
    print("errorrr!!!!")
}



