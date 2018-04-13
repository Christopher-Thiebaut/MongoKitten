import Foundation
import NIO
import BSON
import Crypto

extension DatabaseConnection {
    /// Parses a SCRAM response
    ///
    /// - parameter response: The SCRAM response to parse
    ///
    /// - returns: The Dictionary that's build from the response
    fileprivate func parse(response r: String) -> [String: String] {
        var parsedResponse = [String: String]()
        
        for part in r.split(separator: ",") where String(part).count >= 3 {
            let part = String(part)
            
            if let first = part.first {
                parsedResponse[String(first)] = String(part[part.index(part.startIndex, offsetBy: 2)..<part.endIndex])
            }
        }
        
        return parsedResponse
    }
}

struct Complete: Codable {
    var ok: Double
    var done: Bool?
    var payload: String
    var conversationId: Int
}

extension DatabaseConnection {
    /// Processes the last step(s) in the SASL process
    ///
    /// - parameter payload: The previous payload
    /// - parameter response: The response we got from the server
    /// - parameter signature: The server signatue to verify
    ///
    /// - throws: On authentication failure or an incorrect Server Signature
    private func complete(response: Document, verifying signature: Data, database: String) throws -> Future<Void> {
        let response = try BSONDecoder.decodeOrError(Complete.self, from: response)
        
        if response.ok > 0 && response.done == true {
            let promise = self.eventloop.newPromise(Void.self)
            promise.succeed()
            return promise.futureResult
        }
        
        let finalResponseData = try Data(base64Encoded: response.payload).assert()
        
        guard let finalResponse = String(data: finalResponseData, encoding: .utf8) else {
            throw MongoError.invalidBase64String
        }
        
        let dictionaryResponse = self.parse(response: finalResponse)
        
        guard let v = dictionaryResponse["v"] else {
            throw AuthenticationError.responseParseError(response: response.payload)
        }
        
        let serverSignature = try Data(base64URLEncoded: v).assert()
        
        guard serverSignature == signature else {
            throw AuthenticationError.serverSignatureInvalid
        }
        
        let commandMessage = Message.Query(
            requestId: self.nextRequestId,
            flags: [],
            fullCollection: database + ".$cmd",
            skip: 0,
            return: 1,
            query: [
                "saslContinue": Int32(1),
                "conversationId": response.conversationId,
                "payload": ""
            ]
        )
        
        return send(message: commandMessage).flatMap(to: Void.self) { reply in
            return try self.complete(response: reply.documents.first ?? [:], verifying: signature, database: database)
        }
    }
    
    /// Respond to a challenge
    ///
    /// - parameter details: The authentication details
    /// - parameter previousInformation: The nonce, response and `SCRAMClient` instance
    ///
    /// - throws: When the authentication fails, when Base64 fails
    private func challenge(credentials: MongoCredentials, nonce: String, response: Document) throws -> Future<Void> {
        let response = try BSONDecoder.decodeOrError(Complete.self, from: response)
        
        // If we failed the authentication
        guard response.ok == 1 else {
            throw AuthenticationError.incorrectCredentials
        }
        
        guard
            let stringResponseData = Data(base64Encoded: response.payload),
            let decodedStringResponse = String(data: stringResponseData, encoding: .utf8)
        else {
            throw MongoError.invalidBase64String
        }
        
        let passwordBytes = MD5().update("\(credentials.username):mongo:\(credentials.password)").finalize().hexString
        
        let result = try self.scram.process(decodedStringResponse, username: credentials.username, password: Data(passwordBytes.utf8), usingNonce: nonce)
        
        // Base64 the payload
        let payload = Data(result.proof.utf8).base64EncodedString()
        
        // Send the proof
        let commandMessage = Message.Query(
            requestId: self.nextRequestId,
            flags: [],
            fullCollection: credentials.authDB + ".$cmd",
            skip: 0,
            return: 1,
            query: [
                "saslContinue": Int32(1),
                "conversationId": response.conversationId,
                "payload": payload
            ]
        )
        
        return send(message: commandMessage).flatMap(to: Void.self) { reply in
            return try self.complete(response: reply.documents.first ?? [:], verifying: result.serverSignature, database: credentials.authDB)
        }
    }
    
    /// Authenticates to this database using SASL
    ///
    /// - parameter details: The authentication details
    ///
    /// - throws: When failing authentication, being unable to base64 encode or failing to send/receive messages
    internal func authenticateSASL(_ credentials: MongoCredentials) throws -> Future<Void> {
        let nonce = randomNonce()
        
        let authPayload = scram.authenticate(credentials.username, usingNonce: nonce)
        
        let payload = Data(authPayload.utf8).base64EncodedString()
        
        let message = Message.Query(
            requestId: self.nextRequestId,
            flags: [],
            fullCollection: credentials.authDB + ".$cmd",
            skip: 0,
            return: 1,
            query: [
                "saslStart": Int32(1),
                "mechanism": "SCRAM-SHA-1",
                "payload": payload
            ]
        )
        
        return send(message: message).flatMap(to: Void.self) { reply in
            return try self.challenge(credentials: credentials, nonce: nonce, response: reply.documents.first ?? [:])
        }
    }
}

