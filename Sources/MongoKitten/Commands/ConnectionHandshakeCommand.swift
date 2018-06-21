import Foundation
import BSON

/// - see: https://github.com/mongodb/specifications/blob/master/source/mongodb-handshake/handshake.rst
struct ConnectionHandshakeCommand: MongoDBCommand {
    typealias Reply = ConnectionHandshakeReply
    
    struct ClientDetails: Encodable {
        struct ApplicationDetails: Encodable {
            var name: String
        }
        
        struct DriverDetails: Encodable {
            let name = "MongoKitten"
            let version = "5"
        }
        
        struct OSDetails: Encodable {
            #if os(Linux)
            let type = "Linux"
            let name: String? // TODO: see if we can fill this in
            #elseif os(macOS)
            let type = "Darwin"
            let name: String? = "macOS"
            #elseif os(iOS)
            let type = "Darwin"
            let name: String? = "iOS"
            #elseif os(Windows)
            let type = "Windows"
            let name: String?
            #else
            let type = "unknown"
            let name: String?
            #endif
            
            #if arch(x86_64)
            let architecture: String? = "x86_64"
            #else
            let architecture: String?
            #endif
            
            let version: String? = nil
        }
        
        var application: ApplicationDetails?
        var driver = DriverDetails()
        var os = OSDetails()
        
        #if swift(>=5.2)
        let platform: String? = "Swift 5.2"
        #elseif swift(>=5.1)
        let platform: String? = "Swift 5.1"
        #elseif swift(>=5.0)
        let platform: String? = "Swift 5.0"
        #elseif swift(>=4.2)
        let platform: String? = "Swift 4.2"
        #elseif swift(>=4.1)
        let platform: String? = "Swift 4.1"
        #else
        let platform: String?
        #endif
        
        init(application: ApplicationDetails?) {
            self.application = application
        }
    }
    
    var isMaster: Int32 = 1
    var client: ClientDetails
    
    var namespace: Namespace
    
    init(application: ClientDetails.ApplicationDetails?, collection: Collection) {
        self.client = ClientDetails(application: application)
        self.namespace = collection.namespace
    }
}

/// - see: https://docs.mongodb.com/manual/reference/command/isMaster/index.html
public struct ConnectionHandshakeReply: ServerReplyDecodable {
    typealias Result = ConnectionHandshakeReply
    
    /// A boolean value that reports when this node is writable. If true, then this instance is a primary in a replica set, or a master in a master-slave configuration, or a mongos instance, or a standalone mongod.
    public let ismaster: Bool
    
    /// The maximum permitted size of a BSON object in bytes for this mongod process. If not provided, clients should assume a max size of “16 * 1024 * 1024”.
    public let maxBsonObjectSize: Int?
    
    /// The maximum permitted size of a BSON wire protocol message. The default value is 48000000 bytes.
    public let maxMessageSizeBytes: Int?
    
    /// The maximum number of write operations permitted in a write batch. If a batch exceeds this limit, the client driver divides the batch into smaller groups each with counts less than or equal to the value of this field.
    public let maxWriteBatchSize: Int? // TODO: Handle according to this value
    
    /// Returns the local server time in UTC. This value is an ISO date.
    public let localTime: Date?
    
    /// The time in minutes that a session remains active after its most recent use. Sessions that have not received a new read/write operation from the client or been refreshed with refreshSessions within this threshold are cleared from the cache. State associated with an expired session may be cleaned up by the server at any time.
    ///
    /// Only available when featureCompatibilityVersion is "3.6". See [Backwards Incompatible Features](https://docs.mongodb.com/manual/release-notes/3.6-compatibility/#compatibility-enabled).
    public let logicalSessionTimeoutMinutes: Int?
    
    /// The earliest version of the wire protocol that this mongod or mongos instance is capable of using to communicate with clients.
    public let minWireVersion: Int
    
    /// The latest version of the wire protocol that this mongod or mongos instance is capable of using to communicate with clients.
    public let maxWireVersion: Int                                                      
    
    /// A boolean value that, when true, indicates that the mongod or mongos is running in read-only mode.
    public let readOnly: Bool?
    
    /// Contains the value isdbgrid when isMaster returns from a mongos instance.
    public let msg: String?
    
    /// The name of the current :replica set.
    public let setName: String?
    
    /// The current replica set config version.
    public let setVersion: String?
    
    /// A boolean value that, when true, indicates if the mongod is a secondary member of a replica set.
    public let secondary: Bool?
    
    /// An array of strings in the format of "[hostname]:[port]" that lists all members of the replica set that are neither hidden, passive, nor arbiters.
    ///
    /// Drivers use this array and the isMaster.passives to determine which members to read from.
    public let hosts: [String]?
    
    /// An array of strings in the format of "[hostname]:[port]" listing all members of the replica set which have a members[n].priority of 0.
    ///
    /// This field only appears if there is at least one member with a members[n].priority of 0.
    ///
    /// Drivers use this array and the isMaster.hosts to determine which members to read from.
    public let passives: [String]?
    
    /// An array of strings in the format of "[hostname]:[port]" listing all members of the replica set that are arbiters.
    ///
    /// This field only appears if there is at least one arbiter in the replica set.
    public let arbiters: [String]?
    
    /// A string in the format of "[hostname]:[port]" listing the current primary member of the replica set.
    public let primary: String?
    
    /// A boolean value that, when true, indicates that the current instance is an arbiter. The arbiterOnly field is only present, if the instance is an arbiter.
    public let arbiterOnly: Bool?
    
    /// A boolean value that, when true, indicates that the current instance is passive. The passive field is only present for members with a members[n].priority of 0.
    public let passive: Bool?
    
    /// A boolean value that, when true, indicates that the current instance is hidden. The hidden field is only present for hidden members.
    public let hidden: Bool?
    
    /// A tag set document containing mappings of arbitrary keys and values. These documents describe replica set members in order to customize write concern and read preference and thereby allow configurable data center awareness.
    ///
    /// This field is only present if there are tags assigned to the member. See Configure Replica Set Tag Sets for more information.
    public let tags: Document?
    
    /// The [hostname]:[port] of the member that returned isMaster.
    public let me: String?
    
    /// A unique identifier for each election. Included only in the output of isMaster for the primary. Used by clients to determine when elections occur.
    public let electionId: String? // TODO: Is this the correct type?
    
    // MARK: ServerReplyDecodable
    public var mongoKittenError: MongoKittenError {
        return MongoKittenError(.commandFailure, reason: nil)
    }
    
    public var isSuccessful: Bool {
        return true
    }
    
    public func makeResult(on collection: Collection) throws -> ConnectionHandshakeReply {
        return self
    }
}
