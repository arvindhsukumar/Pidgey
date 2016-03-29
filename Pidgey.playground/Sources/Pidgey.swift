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
    private weak var pidgey: PidgeyBird!
    
    public var task: NSURLSessionTask?
    
    private var originalURL: NSURL!
    public var urlRequest: NSMutableURLRequest!
    
    private var params: [String:AnyObject]?
    private var queryParams: [String: String]?
    
    public var requestSerializationMode: PidgeyRequestSerializationMode = .HTTP
    public var requestBody: NSData?
    
    convenience init(url: NSURL, method: HTTPMethod)
    {
        self.init()
        originalURL = url
        urlRequest = NSMutableURLRequest(URL: url)
        urlRequest.HTTPMethod = method.rawValue
    }
    
    public func resume(completion:(data:NSData?, response:NSURLResponse?, error:NSError?)->())
    {
        setQueryParams()
        setRequestBody()
        setContentType()
        
        let session = pidgey.session
        task = session.dataTaskWithRequest(urlRequest, completionHandler: { (data:NSData?, response:NSURLResponse?, error:NSError?) in
            
            completion(data:data, response:response, error:error)
            
        })
        
        task?.resume()
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
}

extension PidgeyRequest {
    
    private func setContentType()
    {
        // TODO: Set content type for form-multipart
        if requestSerializationMode == .HTTP {
            setHeader("Content-Type", value: "application/x-form-url-encoded")
        }
        else {
            setHeader("Content-Type", value: "application/json")
        }
    }
    
    private func setRequestBody()
    {
        requestBody = serializeParams()
        urlRequest.HTTPBody = requestBody
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
                components += queryComponentsForParam("\(key)", value: value)
            }
        } else {
//            components.appendContentsOf([(percentEncodeString(key), percentEncodeString("\(value)"))])
            components.appendContentsOf([(key, "\(value)")])
        }
        
        return components
    }
    
}

public let Pidgey = PidgeyBird.sharedInstance



