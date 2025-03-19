//
//  User.swift
//  rufkian
//
//  Created by Алексей Степанов on 2025-03-18.
//

import Foundation

struct UserInfo: Decodable {
    let id: String?
    let key: String?
    
    init(_ id: String?, _ key: String?, _ email: String?) {
        self.id = id
        self.key = key
    }
    
    func IsEmpty() -> Bool {
        return id == nil || key == nil
    }
}

func GetUserInfo() -> UserInfo {
    var result = UserInfo(nil, nil, nil)
    
    let config = URLSessionConfiguration.default
    config.httpCookieStorage = HTTPCookieStorage.shared
    config.httpCookieAcceptPolicy = .always
    let session = URLSession(configuration: config)
    
    let task = session.dataTask(with: URLRequest(url: URL(string: "http://localhost:8080/user")!)) { data, response, error in
        if let error = error {
            print(error)
            return
        }

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                print(httpResponse)
                return
            }
        }
        
        if let data = data, let responseString = String(data: data, encoding: .utf8) {
            print(responseString)
        }
        
        do {
            result = try JSONDecoder().decode(UserInfo.self, from: data ?? Data())
        } catch {
            print("error while decoding user info response")
        }
    }
    task.resume()
    
    print(result)
    
    return result
}
