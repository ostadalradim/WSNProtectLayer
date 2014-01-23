module IDSForwarderP
{
	provides {
		interface Send as IDSAlertSend;
		interface Init;
		}
	uses {
		interface AMSend;
		interface Receive;
		interface Pool<message_t> as Pool; 
		interface Queue<message_t*> as SendQueue;
	}
}
implementation{
	message_t* m_msgIDSAlert=NULL;
	uint8_t m_msgIDSAlertLen=0;	
	bool m_lastMsgWasIDSAlert = 0;
	message_t* m_lastMsg;
 	bool m_busy = FALSE;
 	
	//
	// interface Init
	//
	command error_t Init.init(){
                //m_msgIDSAlert = &m_msgMemory;
		return SUCCESS;
	}
	
	task void task_forwardMessage()
	{
		message_t* sendMsg=NULL;
		
		if (m_busy)
		{
			// radio busy,
			dbg("Privacy","Radio in forwarder busy.\n");
			return; 	
		}
		
		if (m_msgIDSAlert != NULL)
		{
			sendMsg=m_msgIDSAlert;
			m_lastMsgWasIDSAlert = TRUE;
			m_msgIDSAlert = NULL;
			
			//send packet
			m_lastMsg = sendMsg;
			if (call AMSend.send(AM_BROADCAST_ADDR, sendMsg, sizeof(IDSMsg_t)) == SUCCESS)
			{
//				printf("task_forwardMessage sent with success\n");
//				printfflush();
				m_busy = TRUE;
				return;
			}
			else
			{
				//send failed,
				dbg("Error","IDSForwarderP task_forward send failed.\n");
				m_lastMsgWasIDSAlert = FALSE;
				signal IDSAlertSend.sendDone(sendMsg, FAIL);
				post task_forwardMessage();
				return;
			}
		}
			
		if (call SendQueue.empty())
		{
			return;
		} else
		{
		   sendMsg = call SendQueue.head();	
		}	
			
		//send packet
		m_lastMsg = sendMsg;
		if (call AMSend.send(AM_BROADCAST_ADDR, sendMsg, sizeof(IDSMsg_t)) == SUCCESS)
		{
//				printf("task_forwardMessage sent with success\n");
//				printfflush();
			m_busy = TRUE;
			call SendQueue.dequeue();
		}
		else
		{
			//send failed,
			dbg("Error","IDSForwarderP task_forward send failed.\n");
			call SendQueue.dequeue();
			call Pool.put(sendMsg);
			post task_forwardMessage();
			return;
		}
			
	}
	//
	// interfrace Receive
	//
	event message_t * Receive.receive(message_t *msg, void *payload, uint8_t len){
		
		if (!call Pool.empty()) 
			{
		   		call SendQueue.enqueue(msg);
		   		post task_forwardMessage();
		   		return call Pool.get();
			}
			else
			{
				dbg("Privacy","ForwarderP, receive buffer full, pool empty.\n");
				return msg;
			}
	}
	
	//
	// interface AMSend
	//
	event void AMSend.sendDone(message_t *msg, error_t error){		
		if (m_lastMsg == msg) {
			if (m_lastMsgWasIDSAlert)
      		{
      			signal IDSAlertSend.sendDone(msg, error); 
      			m_lastMsgWasIDSAlert = FALSE;
      		} else
      		{
      			call Pool.put(msg);
      		}
      		m_busy = FALSE;
      		post task_forwardMessage();
    	}
	}
	//
	// interface IDSAlertSend
	//
	command error_t IDSAlertSend.cancel(message_t *msg) {
		//not working
		return FAIL;
	}
	command void * IDSAlertSend.getPayload(message_t *msg, uint8_t len)
	{
		return call AMSend.getPayload(msg, len);
	}
	
	command uint8_t IDSAlertSend.maxPayloadLength()
	{
		return call AMSend.maxPayloadLength();
	}
	
	command error_t IDSAlertSend.send(message_t *msg, uint8_t len)
	{
		if (m_msgIDSAlert == NULL) 
			{
		   		m_msgIDSAlert = msg;
		   		m_msgIDSAlertLen = len;
		   		post task_forwardMessage();
		   		return SUCCESS;
			}
			else
			{
				return BUSY;
			}
	}

}



