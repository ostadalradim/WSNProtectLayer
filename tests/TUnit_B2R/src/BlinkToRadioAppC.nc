// $Id: BlinkToRadioAppC.nc,v 1.4 2006/12/12 18:22:52 vlahan Exp $

/*
 * "Copyright (c) 2000-2006 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 */

/**
 * Application file for the BlinkToRadio application.  A counter is
 * incremented and a radio message is sent whenever a timer fires.
 * Whenever a radio message is received, the three least significant
 * bits of the counter in the message payload are displayed on the
 * LEDs.  Program two motes with this application.  As long as they
 * are both within range of each other, the LEDs on both will keep
 * changing.  If the LEDs on one (or both) of the nodes stops changing
 * and hold steady, then that node is no longer receiving any messages
 * from the other node.
 *
 * @author Prabal Dutta
 * @date   Feb 1, 2006
 */
#include <Timer.h>
#include <TestCase.h>
#include "BlinkToRadio.h"


configuration BlinkToRadioAppC {
}
implementation {
  components MainC;
  components LedsC;
  components BlinkToRadioC as App;
  components new TimerMilliC() as Timer0;

  components new TestCaseC() as BasicAssertionTestC;
  App.BasicAssertionTest -> BasicAssertionTestC;
  components new TestCaseC() as KeyDistrib_sendEncryptedMessage_TestC;
  App.KeyDistrib_sendEncryptedMessage_Test -> KeyDistrib_sendEncryptedMessage_TestC;
  components new TestCaseC() as KeyDistrib_decryptMessage_Test;
  App.KeyDistrib_decryptMessage_Test -> KeyDistrib_decryptMessage_Test;
  components new TestCaseC() as KeyDistrib_generateAndDeriveKey_Test;
  App.KeyDistrib_generateAndDeriveKey_Test -> KeyDistrib_generateAndDeriveKey_Test;
  components new TestCaseC() as KeyDistrib_useKeyToBS_Test;
  App.KeyDistrib_useKeyToBS_Test -> KeyDistrib_useKeyToBS_Test;



  /*
  ---> Original Components
  components ActiveMessageC;
  components new AMSenderC(AM_BLINKTORADIO);
  components new AMReceiverC(AM_BLINKTORADIO);
  
  ---> Replaced by new ProtectLayerC	
*/
  components ProtectLayerC;
  components KeyDistribC;
  components CryptoC;
  components SharedDataC;

  App.KeyDistrib -> KeyDistribC;
  App.Crypto -> CryptoC;

  App.SharedData -> SharedDataC.SharedData;

  App.Boot -> MainC;
  App.Leds -> LedsC;
  App.Timer0 -> Timer0;

/* 
  ---> Original wirings 
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  ---> Replaced by new one to ProtectLayerC
 */
  App.Packet -> ProtectLayerC.Packet; 
  //App.AMPacket -> PrivacyC; // not used at all
  App.AMControl -> ProtectLayerC.AMControl;
  App.AMSend -> ProtectLayerC.AMSend;
  App.Receive -> ProtectLayerC.Receive;

} 
