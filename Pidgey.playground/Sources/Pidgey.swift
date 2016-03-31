import Foundation

public enum HTTPMethod : String{
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case HEAD = "HEAD"
    case OPTION = "OPTION"
    case PATCH = "PATCH"
}

protocol HeaderName {
    static var headerName: String {get}
}

public enum Header {
    enum ContentType: String, HeaderName {
        static var headerName: String {return "Content-Type"}
        
        case JSON = "application/json"
        case Form = "application/x-www-form-urlencoded"
    
    }
    
    enum Accept: String, HeaderName {
        static var headerName: String {return "Accept"}
        case JSON = "application/json"
        case XML = "application/xml"
        case Text = "application/text"
    }
    
    enum Authorization: HeaderName {
        static var headerName: String {return "Authorization"}
    }
}

public enum Result<T> {
    case Success(T)
    case Failure(ErrorType)
}

internal enum PidgeyError: ErrorType {
    case InvalidURL
}

public class PidgeyBird: NSObject {
    
    public class var sharedInstance: PidgeyBird {
        struct Static {
            static let instance = PidgeyBird()
        }
        return Static.instance
    }
    
    private var session: NSURLSession!
    
    override init(){
        super.init()
        setupSession()
    }
    
    private func setupSession()
    {
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        session = NSURLSession(configuration: config)
    }
    
    private func request(url:String, method: HTTPMethod, params: [String: AnyObject]?, queryParams:[String: String]?) throws -> PidgeyRequest
    {
        guard let url = NSURL(string: url) else {
            throw PidgeyError.InvalidURL
        }
        
        let request = PidgeyRequest(url: url, method: method)
        request.pidgey = self
        request.queryParams = queryParams
        request.params = params
        return request
    }
    
    public func GET(url:String, queryParams:[String:String]?) throws -> PidgeyRequest
    {
        let request = try self.request(url, method: .GET, params:nil,queryParams:queryParams)
        return request
    }
    
    public func POST(url:String, params:[String:AnyObject], queryParams:[String:String]? = nil) throws -> PidgeyRequest
    {
        let request = try self.request(url, method: .POST, params: params, queryParams:queryParams)
        return request
    }
}

public enum PidgeyRequestSerializationMode {
    case HTTP
    case JSON
}

public class PidgeyRequest
{
    private weak var pidgey: PidgeyBird?
    
    private var originalURL: NSURL
    public var urlRequest: NSMutableURLRequest
    public var task: NSURLSessionTask?

    private var params: [String:AnyObject]?
    private var queryParams: [String: String]?
    
    public var requestSerializationMode: PidgeyRequestSerializationMode = .HTTP
    private var requestBody: NSData? {
        return urlRequest.HTTPBody
    }
    public var taskIdentifier: Int? {
        return task?.taskIdentifier
    }
    
    init(url: NSURL, method: HTTPMethod)
    {
        originalURL = url
        urlRequest = NSMutableURLRequest(URL: url)
        urlRequest.HTTPMethod = method.rawValue
    }
    
    public func resume(completion:(response:PidgeyResponse?, error:NSError?)->())
    {
        setQueryParams()
        setRequestBody()
        setContentType()
        
        let session = pidgey?.session
        task = session?.dataTaskWithRequest(urlRequest, completionHandler: { (data:NSData?, response:NSURLResponse?, error:NSError?) in
            let pidgeyResponse = PidgeyResponse(request: self, data: data, urlResponse: response as? NSHTTPURLResponse)
            
            completion(response:pidgeyResponse, error:error)
        })
        
        task?.resume()
    }
    
}

extension PidgeyRequest {
    
    private func setContentType()
    {
        // TODO: Set content type for form-multipart
        if requestSerializationMode == .JSON {
            setHeader(Header.ContentType.headerName, value: Header.ContentType.JSON.rawValue)
        }
        else {
            setHeader(Header.ContentType.headerName, value: Header.ContentType.Form.rawValue)
        }
    }
    
    private func setRequestBody()
    {
        urlRequest.HTTPBody = serializeParams()
    }
    
    private func setQueryParams()
    {
        let queryParams = self.queryParams ?? [:]
        let components = NSURLComponents(URL: originalURL, resolvingAgainstBaseURL: false)
        var newQueryItems: [NSURLQueryItem] = []
        for (key, value) in queryParams {
            let queryItem = NSURLQueryItem(name: key, value: value)
            newQueryItems.append(queryItem)
        }
        var existingQueryItems = components?.queryItems ?? []
        existingQueryItems.appendContentsOf(newQueryItems)
        components?.queryItems = existingQueryItems
        
        urlRequest.URL = components?.URL
    }
    
    public func setHeader(header: String, value: String)
    {
        urlRequest.setValue(value, forHTTPHeaderField: header)
    }
    
    public func setHeaders(headers:[String:String])
    {
        urlRequest.allHTTPHeaderFields = nil
        for (key, value) in headers {
            setHeader(key, value: value)
        }
    }
    
    private func addHeaders(headers:[String:String])
    {
        for (k,v) in headers {
            setHeader(k, value: v)
        }
    }

    public func setCookies(cookies:[String:String])
    {
        var httpCookies: [NSHTTPCookie] = []
        for (k,v) in cookies {
            if let cookie = NSHTTPCookie(properties: [
                NSHTTPCookieName: k,
                NSHTTPCookieValue: v,
                NSHTTPCookieOriginURL: self.originalURL,
                NSHTTPCookiePath: "/"
            ]) {
                httpCookies.append(cookie)
            }
        }
        
        let cookieHeaders = NSHTTPCookie.requestHeaderFieldsWithCookies(httpCookies)
        addHeaders(cookieHeaders)
    }
    
    public func setAuthentication(username username:String, password: String)
    {
        let authString = "\(username):\(password)"
        let utf8str = authString.dataUsingEncoding(NSUTF8StringEncoding)
        
        if let base64Encoded = utf8str?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        {
            setHeader(Header.Authorization.headerName, value: "Basic \(base64Encoded)")
        }
    }
}

extension PidgeyRequest {
    
    private func serializeParams() -> NSData?
    {
        guard let params = params else {return nil}
        
        var data: NSData?
        if requestSerializationMode == .JSON {
            data = try? NSJSONSerialization.dataWithJSONObject(params, options: [NSJSONWritingOptions.PrettyPrinted])
        }
        else {
            data = formEncodedParams()?.dataUsingEncoding(NSUTF8StringEncoding)
        }
        
        return data
    }
    
    private func formEncodedParams() -> String?
    {
        guard let params = params else {return nil}
        
        var components: [(String, String)] = []
        for (key, value) in params {
            components += queryComponentsForParam(key, value: value)
        }
        
        return (components.map({return "\($0)=\($1)"}) as [String]).joinWithSeparator("&")
    }
    
    private func queryComponentsForParam(key: String, value: AnyObject) -> [(String,String)]
    {
        var components: [(String, String)] = []
        if let dictionary = value as? [String: AnyObject] {
            for (nestedKey, value) in dictionary {
                components += queryComponentsForParam("\(key)[\(nestedKey)]", value:value)
            }
        } else if let array = value as? [AnyObject] {
            for value in array {
                components += queryComponentsForParam("\(key)[]", value: value)
            }
        } else {
            components.appendContentsOf([(percentEncodeString(key), percentEncodeString(value as? String))])
        }
        
        return components
    }
    
    private func percentEncodeString(string:String?) -> String {
        return string?.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) ?? ""
    }
}

public struct PidgeyResponse {
    private weak var request: PidgeyRequest?
    public var urlResponse: NSHTTPURLResponse?
    public var data: NSData?
    public var json: AnyObject? {
        if let data = data {
            return try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0))
        }
        return nil
    }
    public var text: String? {
        if let data = data {
            return String(data: data, encoding: NSUTF8StringEncoding)
        }
        return nil
    }
    public var statusCode: Int? {
        return urlResponse?.statusCode
    }
    
    init(request: PidgeyRequest, data: NSData?, urlResponse: NSHTTPURLResponse?) {
        self.data = data
        self.urlResponse = urlResponse
        self.request = request
    }
}

public let Pidgey = PidgeyBird.sharedInstance



