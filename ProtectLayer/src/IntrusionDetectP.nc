/**
 * Module IntrusionDetectP implements interfaces provided by configuration IntrusionDetectC.
 * 	@version   1.0
 * 	@date      2012-2014
 */

#include "ProtectLayerGlobals.h"

module IntrusionDetectP {
#ifndef THIS_IS_BS
    uses {
        //		interface AMSend;
        //		interface Receive;
        interface Receive as ReceiveMsgCopy;
        interface Receive as ReceiveIDSMsgCopy;
        interface SharedData;
        interface IDSBuffer;
        interface AMSend;// as IDSAlertSend;
        interface Crypto;
        interface AMPacket;
        interface Packet;
        interface Route;
    }
#endif
    provides {
        interface Init;
        interface Init as PLInit;
        interface IntrusionDetect;
    }
}

implementation {
#ifndef THIS_IS_BS
    message_t m_msg;
    
    // Logging
    message_t* m_logMsg;
    message_t* m_lastLogMsg;
    message_t m_memLogMsg;
    message_t pkt;
    //	bool m_storageBusy = FALSE;
    
    bool m_radioBusy = FALSE;
    SavedData_t*    pSavedData = NULL;
    //NODE_REPUTATION reputation;
    SavedData_t* savedData;
    IDS_STATUS ids_status = IDS_ON;
    uint8_t alertCounter = 0;
    //	uint32_t offset_write = 0;
    
    static const char *TAG = "IntrusionDetectP";
    
    
    //
    //	Init interface
    //
    command error_t Init.init() {
        
        m_logMsg = &m_memLogMsg;
        
        return SUCCESS;
    }
    
    // Reputation is currently not calculated because of memory limitations:
    
    //	command NODE_REPUTATION IntrusionDetect.getNodeReputation(uint8_t nodeid) {
    //		//savedData = call SharedData.getNodeState(nodeid);
    //		//reputation = (*savedData).idsData.neighbor_reputation;
    //		reputation =  (*call SharedData.getNodeState(nodeid)).idsData.neighbor_reputation;
    //                dbg("IDSState", "Reputation of node %d is: %d.\n", nodeid, reputation);
    //		return reputation;
    //	}
    
    command error_t PLInit.init()
    {
        pSavedData = call SharedData.getSavedData();
        return SUCCESS;
    }
    
    command void IntrusionDetect.switchIDSoff(){
        ids_status = IDS_OFF;
    }
    
    command void IntrusionDetect.switchIDSon(){
        ids_status = IDS_ON;
    }
    
    command void IntrusionDetect.resetIDS(){
    	call IDSBuffer.resetBuffer();

    }
    
    
    // Messages passed to the IDS from privacy component
    event message_t * ReceiveMsgCopy.receive(message_t *msg, void *payload, uint8_t len){
        
        uint32_t hashedPacket;
        
        SPHeader_t* spHeader;        
        spHeader = (SPHeader_t*) payload;

		// If the IDS is off => return
		if (ids_status == IDS_OFF) {
			return msg;
		}

        pl_printf("IDSState: A copy of a message from Privacy component received. Sender is %d.\n", spHeader->sender);

        savedData = call SharedData.getNodeState(spHeader->receiver);
        
        if (savedData == NULL && call SharedData.getNodeState(spHeader->sender) == NULL ) {
            return msg;
        }
        
        if ( savedData != NULL) {
        	// If nb of received packets is higher than size of its type, assign 0 to both received and forwardwed packets
        	if (savedData->idsData.nb_received >= 4294967295u) {
        		savedData->idsData.nb_received = 0;
        		savedData->idsData.nb_forwarded = 0;
        		pl_printf("IDSState: counters of received and forwarded packets were reset.\n");
        	}
            savedData->idsData.nb_received++;

            pl_printf("IDSState: Receiver %d is our neighbor, PRR incremented.\n", spHeader->receiver); 

        }
        
        //        msgType = spHeader->msgType;
        if (len < sizeof(SPHeader_t)){
        	return msg;
        }
        
        call Crypto.hashDataShortB( ((uint8_t*) payload), sizeof(SPHeader_t), len - sizeof(SPHeader_t), &hashedPacket);
        
        // AES (or another cryptographic function) of the payload should be computed in order
        // to identify content of the messages
        call IDSBuffer.insertOrUpdate(&spHeader->sender, &spHeader->receiver, &hashedPacket);
        
        
        return msg;
        
    }
    
    event void IDSBuffer.oldestPacketRemoved(uint16_t sender, uint16_t receiver){
        
        IDSMsg_t* idspkt;
        
        uint16_t dropping;
        
        savedData = call SharedData.getNodeState(receiver);

        dropping = savedData->idsData.nb_forwarded * 100 / savedData->idsData.nb_received;

        pl_printf("IDSState: Neighbor %d dropped a packet. IDS alert may be sent. Alert counter: %d\n", receiver, alertCounter);
        
        pl_printf("IDSState: Packet forwarded: %lu\n. Packet received: %lu. Dropping: %d\n.", savedData->idsData.nb_forwarded, savedData->idsData.nb_received, (100-dropping) );        
        
        // Did we listen enough packets from the node?
        if (savedData->idsData.nb_received > IDS_MIN_PACKET_RECEIVED) {
        	// Is the dropping ration higher than threshold?
            if ( dropping < IDS_DROPPING_THRESHOLD ) {
            	// Send IDS alert to the BS!
                if (!m_radioBusy) {
                    idspkt = (IDSMsg_t*)(call Packet.getPayload(&pkt, sizeof(IDSMsg_t)));
                    if (idspkt == NULL) {
                        return;
                    }

                    // We do not send alert after any packet received.
                    alertCounter++;
                    if (alertCounter > 1) {
                    	if (alertCounter >= 10) {
                    		alertCounter = 0;
                    	}
                    	return;
                    }
                    pl_printf("IDSState: Neighbor %d dropped too many packets. IDS alert will be sent.\n", receiver);
                    
                    idspkt->source = TOS_NODE_ID;
                    idspkt->sender = TOS_NODE_ID;
                    idspkt->receiver = call Route.getParentID();
                    idspkt->nodeID = receiver;
                    idspkt->dropping = (uint16_t) 100 - dropping;
                    
                    if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(IDSMsg_t)) == SUCCESS) {
                        m_radioBusy = TRUE;
                    }
                }	
            }
        }
    }
    
    event void IDSBuffer.packetForwarded(uint16_t sender, uint16_t receiver){
        savedData = call SharedData.getNodeState(sender);
        savedData->idsData.nb_forwarded++;

        pl_printf("IDSState: Neighbor %d forwarded packet.\n", sender); 

    }
    
    /**
     * Event: Some IDS alert was received from Dispatcher - IDS alert
     */
    event message_t * ReceiveIDSMsgCopy.receive(message_t *msg, void *payload, uint8_t len){
    	
        uint32_t hashedPacket;
        uint16_t sender;
        uint16_t receiver;
        IDSMsg_t* idsmsg;
		idsmsg = (IDSMsg_t*)payload;
        sender = idsmsg->sender;
        receiver = idsmsg->receiver;

		// If the IDS is off => return
    	if (ids_status == IDS_OFF) {
    		return msg;
    	}

        pl_printf("IDSState: A copy of an IDSAlert from IDSForwarder received. Sender: %d, receiver: %d.\n", sender, receiver); 

		savedData = call SharedData.getNodeState(receiver); 
        
        if (call SharedData.getNodeState(sender) == NULL && savedData == NULL ) {
            return msg;
        }
        
        if ( savedData != NULL) {
        	// If nb of received packets is higher than size of its type, assign 0 to both received and forwardwed packets
        	if (savedData->idsData.nb_received >= 4294967295u) {
        		savedData->idsData.nb_received = 0;
        		savedData->idsData.nb_forwarded = 0;
        		pl_printf("IDSState: counters of received and forwarded packets were reset.\n");
        	}
            savedData->idsData.nb_received++;

            pl_printf("IDSState: Receiver %d is our neighbor, PRR incremented.\n", receiver); 

        }
        
        if (len < sizeof(SPHeader_t)){
        	return msg;
        }
        
        call Crypto.hashDataShortB( ((uint8_t*) payload) + sizeof(SPHeader_t), 0, len - sizeof(SPHeader_t), &hashedPacket);
        
        // AES (or another cryptographic function) of the payload should be computed in order
        // to identify content of the messages
        // Buffer for each of the node will contain:
        // Sender id, Receiver id, Content, RSSI?
        call IDSBuffer.insertOrUpdate(&sender, &receiver, &hashedPacket);
        
        return msg;
    }
    
    
    event void AMSend.sendDone(message_t *msg, error_t error){
        m_radioBusy = FALSE;
    }
    
#else
 	
    command error_t Init.init() {
        return SUCCESS;
    }
    command error_t PLInit.init(){
        return SUCCESS;
    }
    command void IntrusionDetect.switchIDSoff(){
    }
    command void IntrusionDetect.switchIDSon(){
    }
    command void IntrusionDetect.resetIDS(){
    }
#endif
}
