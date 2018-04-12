import Foundation
import libmongoc

/// A protocol for monitoring events to implement, specifying their type and name.
public protocol MongoEvent {
    /// The MongoEventType corresponding to the event. This event will be posted if 
    /// monitoring is enabled for its eventType.
    static var eventType: MongoEventType { get }

    /// The name this event will be posted under.
    static var eventName: Notification.Name { get }
}

/// A protocol for monitoring events to implement, indicating that they can be initialized from an OpaquePointer
/// to the corresponding libmongoc type.
private protocol InitializableFromOpaquePointer {
    /// Initializes the event from an OpaquePointer.
    init(_ event: OpaquePointer)
}

/// An event published when a command starts. The event is stored under the key `event`
/// in the `userInfo` property of `Notification`s posted under the name .commandStarted.
public struct CommandStartedEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .commandMonitoring }

    /// The name this event will be posted under.
    public static var eventName: Notification.Name { return .commandStarted }

    /// The command.
    let command: Document

    /// The database name.
    let databaseName: String

    /// The command name.
    let commandName: String

    /// The driver generated request id.
    let requestId: Int64

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    let operationId: Int64

    /// The connection id for the command.
    let connectionId: ConnectionId

    /// Initializes a CommandStartedEvent from an OpaquePointer to a mongoc_apm_command_started_t
    fileprivate init(_ event: OpaquePointer) {
        let commandData = UnsafeMutablePointer(mutating: mongoc_apm_command_started_get_command(event)!)
        self.command = Document(fromPointer: commandData)
        self.databaseName = String(cString: mongoc_apm_command_started_get_database_name(event))
        self.commandName = String(cString: mongoc_apm_command_started_get_command_name(event))
        self.requestId = mongoc_apm_command_started_get_request_id(event)
        self.operationId = mongoc_apm_command_started_get_operation_id(event)
        self.connectionId = ConnectionId(mongoc_apm_command_started_get_host(event))
    }
}

/// An event published when a command succeeds. The event is stored under the key `event`
/// in the `userInfo` property of `Notification`s posted under the name .commandSucceeded.
public struct CommandSucceededEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .commandMonitoring }

    /// The name this event will be posted under.
    public static var eventName: Notification.Name { return .commandSucceeded }

    /// The execution time of the event, in microseconds.
    let duration: Int64

    /// The command reply.
    let reply: Document

    /// The command name.
    let commandName: String

    /// The driver generated request id.
    let requestId: Int64

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    let operationId: Int64

    /// The connection id for the command.
    let connectionId: ConnectionId

    /// Initializes a CommandSucceededEvent from an OpaquePointer to a mongoc_apm_command_succeeded_t
    fileprivate init(_ event: OpaquePointer) {
        self.duration = mongoc_apm_command_succeeded_get_duration(event)
        let replyData = UnsafeMutablePointer(mutating: mongoc_apm_command_succeeded_get_reply(event)!)
        self.reply = Document(fromPointer: replyData)
        self.commandName = String(cString: mongoc_apm_command_succeeded_get_command_name(event))
        self.requestId = mongoc_apm_command_succeeded_get_request_id(event)
        self.operationId = mongoc_apm_command_succeeded_get_operation_id(event)
        self.connectionId = ConnectionId(mongoc_apm_command_succeeded_get_host(event))
    }
}

/// An event published when a command fails. The event is stored under the key `event`
/// in the `userInfo` property of `Notification`s posted under the name .commandFailed.
public struct CommandFailedEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .commandMonitoring }

    /// The name this event will be posted under.
    public static var eventName: Notification.Name { return .commandFailed }

    /// The execution time of the event, in microseconds.
    let duration: Int64

    /// The command name.
    let commandName: String

    /// The failure, represented as a MongoError.
    let failure: MongoError

    /// The client generated request id.
    let requestId: Int64

    /// The driver generated operation id. This is used to link events together such
    /// as bulk write operations.
    let operationId: Int64

    /// The connection id for the command.
    let connectionId: ConnectionId

    /// Initializes a CommandFailedEvent from an OpaquePointer to a mongoc_apm_command_failed_t
    fileprivate init(_ event: OpaquePointer) {
        self.duration = mongoc_apm_command_failed_get_duration(event)
        self.commandName = String(cString: mongoc_apm_command_failed_get_command_name(event))
        var error = bson_error_t()
        mongoc_apm_command_failed_get_error(event, &error)
        self.failure = MongoError.commandError(message: toErrorString(error))
        self.requestId = mongoc_apm_command_failed_get_request_id(event)
        self.operationId = mongoc_apm_command_failed_get_operation_id(event)
        self.connectionId = ConnectionId(mongoc_apm_command_failed_get_host(event))
    }
}

/// Published when a server description changes. This does NOT include changes to the server's roundTripTime property.
public struct ServerDescriptionChangedEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .serverMonitoring }

    /// The name this event will be posted under. 
    public static var eventName: Notification.Name { return .serverDescriptionChanged }

    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    /// A unique identifier for the topology.
    let topologyId: ObjectId

    /// The previous server description.
    let previousDescription: ServerDescription

    /// The new server description.
    let newDescription: ServerDescription

    /// Initializes a ServerDescriptionChangedEvent from an OpaquePointer to a mongoc_server_changed_t
    fileprivate init(_ event: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_apm_server_changed_get_host(event))
        var oid = bson_oid_t()
        mongoc_apm_server_changed_get_topology_id(event, &oid)
        self.topologyId = ObjectId(fromPointer: &oid)
        self.previousDescription = ServerDescription(mongoc_apm_server_changed_get_previous_description(event))
        self.newDescription = ServerDescription(mongoc_apm_server_changed_get_new_description(event))
    }
}

/// Published when a server is initialized.
public struct ServerOpeningEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .serverMonitoring }

    /// The name this event will be posted under. 
    public static var eventName: Notification.Name { return .serverOpening }

    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    /// A unique identifier for the topology.
    let topologyId: ObjectId

    /// Initializes a ServerOpeningEvent from an OpaquePointer to a mongoc_apm_server_opening_t
    fileprivate init(_ event: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_apm_server_opening_get_host(event))
        var oid = bson_oid_t()
        mongoc_apm_server_opening_get_topology_id(event, &oid)
        self.topologyId = ObjectId(fromPointer: &oid)
    }
}

/// Published when a server is closed.
public struct ServerClosedEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .serverMonitoring }

    /// The name this event will be posted under. 
    public static var eventName: Notification.Name { return .serverClosed }

    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    /// A unique identifier for the topology.
    let topologyId: ObjectId

    /// Initializes a TopologyClosedEvent from an OpaquePointer to a mongoc_apm_topology_closed_t
    fileprivate init(_ event: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_apm_server_closed_get_host(event))
        var oid = bson_oid_t()
        mongoc_apm_server_closed_get_topology_id(event, &oid)
        self.topologyId = ObjectId(fromPointer: &oid)
    }
}

/// Published when a topology description changes.
public struct TopologyDescriptionChangedEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .serverMonitoring }

    /// The name this event will be posted under. 
    public static var eventName: Notification.Name { return .topologyDescriptionChanged }

    /// A unique identifier for the topology.
    let topologyId: ObjectId

    /// The old topology description.
    let previousDescription: TopologyDescription

    /// The new topology description.
    let newDescription: TopologyDescription

    /// Initializes a TopologyDescriptionChangedEvent from an OpaquePointer to a mongoc_apm_topology_changed_t
    fileprivate init(_ event: OpaquePointer) {
        var oid = bson_oid_t()
        mongoc_apm_topology_changed_get_topology_id(event, &oid)
        self.topologyId = ObjectId(fromPointer: &oid)
        self.previousDescription = TopologyDescription(mongoc_apm_topology_changed_get_previous_description(event))
        self.newDescription = TopologyDescription(mongoc_apm_topology_changed_get_new_description(event))
    }
}

/// Published when a topology is initialized.
public struct TopologyOpeningEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .serverMonitoring }

    /// The name this event will be posted under. 
    public static var eventName: Notification.Name { return .topologyOpening }

    /// A unique identifier for the topology.
    let topologyId: ObjectId

    /// Initializes a TopologyOpeningEvent from an OpaquePointer to a mongoc_apm_topology_opening_t
    fileprivate init(_ event: OpaquePointer) {
        var oid = bson_oid_t()
        mongoc_apm_topology_opening_get_topology_id(event, &oid)
        self.topologyId = ObjectId(fromPointer: &oid)
    }
}

/// Published when a topology is closed.
public struct TopologyClosedEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .serverMonitoring }

    /// The name this event will be posted under.
    public static var eventName: Notification.Name { return .topologyClosed }

    /// A unique identifier for the topology.
    let topologyId: ObjectId

    /// Initializes a TopologyClosedEvent from an OpaquePointer to a mongoc_apm_topology_closed_t
    fileprivate init(_ event: OpaquePointer) {
        var oid = bson_oid_t()
        mongoc_apm_topology_closed_get_topology_id(event, &oid)
        self.topologyId = ObjectId(fromPointer: &oid)
    }
}

/// Published when the server monitor’s ismaster command is started - immediately before
/// the ismaster command is serialized into raw BSON and written to the socket.
public struct ServerHeartbeatStartedEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .serverMonitoring }

    /// The name this event will be posted under.
    public static var eventName: Notification.Name { return .serverHeartbeatStarted }

    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    /// Initializes a ServerHeartbeatStartedEvent from an OpaquePointer to a mongoc_apm_server_heartbeat_started_t
    fileprivate init(_ event: OpaquePointer) {
        self.connectionId = ConnectionId(mongoc_apm_server_heartbeat_started_get_host(event))
    }
}

/// Published when the server monitor’s ismaster succeeds.
public struct ServerHeartbeatSucceededEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .serverMonitoring }

    /// The name this event will be posted under.
    public static var eventName: Notification.Name { return .serverHeartbeatSucceeded }

    /// The execution time of the event, in microseconds.
    let duration: Int64

    /// The command reply.
    let reply: Document

    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    /// Initializes a ServerHeartbeatSucceededEvent from an OpaquePointer to a mongoc_apm_server_heartbeat_succeeded_t
    fileprivate init(_ event: OpaquePointer) {
        self.duration = mongoc_apm_server_heartbeat_succeeded_get_duration(event)
        let replyData = UnsafeMutablePointer(mutating: mongoc_apm_server_heartbeat_succeeded_get_reply(event)!)
        self.reply = Document(fromPointer: replyData)
        self.connectionId = ConnectionId(mongoc_apm_server_heartbeat_succeeded_get_host(event))
    }
}

/// Published when the server monitor’s ismaster fails, either with an “ok: 0” or a socket exception.
public struct ServerHeartbeatFailedEvent: MongoEvent, InitializableFromOpaquePointer {
    /// The type of this event.
    public static var eventType: MongoEventType { return .serverMonitoring }

    /// The name this event will be posted under. 
    public static var eventName: Notification.Name { return .serverHeartbeatFailed }

    /// The execution time of the event, in microseconds.
    let duration: Int64

    /// The failure. 
    let failure: MongoError

    /// The connection ID (host/port pair) of the server.
    let connectionId: ConnectionId

    /// Initializes a ServerHeartbeatFailedEvent from an OpaquePointer to a mongoc_apm_server_heartbeat_failed_t
    fileprivate init(_ event: OpaquePointer) {
        self.duration = mongoc_apm_server_heartbeat_failed_get_duration(event)
        var error = bson_error_t()
        mongoc_apm_server_heartbeat_failed_get_error(event, &error)
        self.failure = MongoError.commandError(message: toErrorString(error))
        self.connectionId = ConnectionId(mongoc_apm_server_heartbeat_failed_get_host(event))
    }
}

/// Callbacks that will be set for events with the corresponding names if the user enables 
/// notifications for those events. These functions generate new `Notification`s and post 
/// them to the `NotificationCenter` that was by the user, or `NotificationCenter.default`
/// if none was specified.

/// A callback that will be set for "command started" events if the user enables command monitoring.
private func commandStarted(_event: OpaquePointer?) {
    postNotification(type: CommandStartedEvent.self, _event: _event, contextFunc: mongoc_apm_command_started_get_context)
}

/// A callback that will be set for "command succeeded" events if the user enables command monitoring.
private func commandSucceeded(_event: OpaquePointer?) {
    postNotification(type: CommandSucceededEvent.self, _event: _event, contextFunc: mongoc_apm_command_succeeded_get_context)
}

/// A callback that will be set for "command failed" events if the user enables command monitoring.
private func commandFailed(_event: OpaquePointer?) {
    postNotification(type: CommandFailedEvent.self, _event: _event, contextFunc: mongoc_apm_command_failed_get_context)
}

/// A callback that will be set for "server description changed" events if the user enables server monitoring.
private func serverDescriptionChanged(_event: OpaquePointer?) {
    postNotification(type: ServerDescriptionChangedEvent.self, _event: _event, contextFunc: mongoc_apm_server_changed_get_context)
}

/// A callback that will be set for "server opening" events if the user enables server monitoring.
private func serverOpening(_event: OpaquePointer?) {
    postNotification(type: ServerOpeningEvent.self, _event: _event, contextFunc: mongoc_apm_server_opening_get_context)
}

/// A callback that will be set for "server closed" events if the user enables server monitoring.
private func serverClosed(_event: OpaquePointer?) {
    postNotification(type: ServerClosedEvent.self, _event: _event, contextFunc: mongoc_apm_server_closed_get_context)
}

/// A callback that will be set for "topology description changed" events if the user enables server monitoring.
private func topologyDescriptionChanged(_event: OpaquePointer?) {
    postNotification(type: TopologyDescriptionChangedEvent.self, _event: _event, contextFunc: mongoc_apm_topology_changed_get_context)
}

/// A callback that will be set for "topology opening" events if the user enables server monitoring.
private func topologyOpening(_event: OpaquePointer?) {
    postNotification(type: TopologyOpeningEvent.self, _event: _event, contextFunc: mongoc_apm_topology_opening_get_context)
}

/// A callback that will be set for "topology closed" events if the user enables server monitoring.
private func topologyClosed(_event: OpaquePointer?) {
    postNotification(type: TopologyClosedEvent.self, _event: _event, contextFunc: mongoc_apm_topology_closed_get_context)
}

/// A callback that will be set for "server heartbeat started" events if the user enables server monitoring.
private func serverHeartbeatStarted(_event: OpaquePointer?) {
    postNotification(type: ServerHeartbeatStartedEvent.self, _event: _event, contextFunc: mongoc_apm_server_heartbeat_started_get_context)
}

/// A callback that will be set for "server heartbeat succeeded" events if the user enables server monitoring.
private func serverHeartbeatSucceeded(_event: OpaquePointer?) {
    postNotification(type: ServerHeartbeatSucceededEvent.self, _event: _event, contextFunc: mongoc_apm_server_heartbeat_succeeded_get_context)
}

/// A callback that will be set for "server heartbeat failed" events if the user enables server monitoring.
private func serverHeartbeatFailed(_event: OpaquePointer?) {
    postNotification(type: ServerHeartbeatFailedEvent.self, _event: _event, contextFunc: mongoc_apm_server_heartbeat_failed_get_context)
}

/// Posts a Notification with the specified name, containing an event of type T generated using the provided _event 
/// and context function.
private func postNotification<T: MongoEvent>(type: T.Type, _event: OpaquePointer?,
                                            contextFunc: (OpaquePointer) -> UnsafeMutableRawPointer!) where T: InitializableFromOpaquePointer {
    guard let event = _event else {
        preconditionFailure("Missing event pointer for \(type)")
    }
    guard let context = contextFunc(event) else {
        preconditionFailure("Missing context for \(type)")
    }

    let client = Unmanaged<MongoClient>.fromOpaque(context).takeUnretainedValue()

    if let center = client.notificationCenter, let enabledTypes = client.monitoringEventTypes {
        if enabledTypes.contains(type.eventType) {
            let eventStruct = type.init(event)
            let notification = Notification(name: type.eventName, userInfo: ["event": eventStruct])
            center.post(notification)
        }
    }
}

/// Extend Notification.Name to have class properties corresponding to each type
/// of event. This allows creating notifications and observers using these names.
extension Notification.Name {
    static let commandStarted = Notification.Name("commandStarted")
    static let commandSucceeded = Notification.Name("commandSucceeded")
    static let commandFailed = Notification.Name("commandFailed")
    static let serverDescriptionChanged = Notification.Name("serverDescriptionChanged")
    static let serverOpening = Notification.Name("serverOpening")
    static let serverClosed = Notification.Name("serverClosed")
    static let topologyDescriptionChanged = Notification.Name("topologyDescriptionChanged")
    static let topologyOpening = Notification.Name("topologyOpening")
    static let topologyClosed = Notification.Name("topologyClosed")
    static let serverHeartbeatStarted = Notification.Name("serverHeartbeatStarted")
    static let serverHeartbeatSucceeded = Notification.Name("serverHeartbeatSucceeded")
    static let serverHeartbeatFailed = Notification.Name("serverHeartbeatFailed")
}

/// The two categories of events. One or both can be enabled for a MongoClient.
public enum MongoEventType {
    // Encompasses events named .commandStarted, .commandSucceeded, .commandFailed events
    case commandMonitoring
    // Encompasses events named .serverChanged, .serverOpening, .serverClosed,
    // .topologyChangedEvent, .topologyOpening, .topologyClosed,
    // .serverHeartbeatStarted, .serverHeartbeatClosed, .serverHeartbeatFailed
    case serverMonitoring
}

/// An extension of MongoClient to add monitoring capability for commands and server discovery and monitoring.
extension MongoClient {
    /// Internal function to install all monitoring callbacks for tbis client. This is used if the MongoClient
    /// is initialized with eventMonitoring = true
    internal func initializeMonitoring() {
        let callbacks = mongoc_apm_callbacks_new()
        mongoc_apm_set_command_started_cb(callbacks, commandStarted)
        mongoc_apm_set_command_succeeded_cb(callbacks, commandSucceeded)
        mongoc_apm_set_command_failed_cb(callbacks, commandFailed)
        mongoc_apm_set_server_changed_cb(callbacks, serverDescriptionChanged)
        mongoc_apm_set_server_opening_cb(callbacks, serverOpening)
        mongoc_apm_set_server_closed_cb(callbacks, serverClosed)
        mongoc_apm_set_topology_changed_cb(callbacks, topologyDescriptionChanged)
        mongoc_apm_set_topology_opening_cb(callbacks, topologyOpening)
        mongoc_apm_set_topology_closed_cb(callbacks, topologyClosed)
        mongoc_apm_set_server_heartbeat_started_cb(callbacks, serverHeartbeatStarted)
        mongoc_apm_set_server_heartbeat_succeeded_cb(callbacks, serverHeartbeatSucceeded)
        mongoc_apm_set_server_heartbeat_failed_cb(callbacks, serverHeartbeatFailed)
        // we can pass this as unretained because the callbacks are stored on the mongoc_client_t, so
        // if the callback is being executed, the client must still be valid
        mongoc_client_set_apm_callbacks(self._client, callbacks, Unmanaged.passUnretained(self).toOpaque())
        mongoc_apm_callbacks_destroy(callbacks)
    }

    /*  
     *  Disables monitoring for this MongoClient. Notifications can be reenabled using MongoClient.enableMonitoring.
     */
    public func disableMonitoring() {
        self.monitoringEventTypes = nil
        self.notificationCenter = nil
    }

    /*
     *  Enables monitoring for this MongoClient for the event type specified, or both types if neither is specified.
     *  Sets the destination NotificationCenter to the one provided, or the application's default NotificationCenter
     *  if one is not specified.
     *
     *  - Parameters:
     *      - forEvents:   A MongoEventType? to enable monitoring for, defaulting to nil. If unspecified, monitoring
     *                     will be enabled for both .commandMonitoring and .serverMonitoring events.
            - usingCenter: A NotificationCenter that event notifications should be posted to, defaulting to the default
                           NotificationCenter for the application.
     *
     */
    public func enableMonitoring(forEvents eventType: MongoEventType? = nil,
                                usingCenter center: NotificationCenter = NotificationCenter.default) {
        if let type = eventType {
            self.monitoringEventTypes = [type]
        } else {
            self.monitoringEventTypes = [.commandMonitoring, .serverMonitoring]
        }
        self.notificationCenter = center
    }
}