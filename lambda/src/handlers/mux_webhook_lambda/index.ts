// Import required AWS SDK clients and commands for Node.js. Note that this requires
// the `@aws-sdk/client-ses` module to be either bundled with this code or included
// as a Lambda layer.
import { SQSHandler, SQSEvent/*, Context */ } from "aws-lambda";
import { getEventbridge, getMux, verifyMessageAsync } from "/opt/nodejs/utils";
import Mux from '@mux/mux-node';
import { EventBridgeClient, PutEventsCommand } from "@aws-sdk/client-eventbridge"

let mux: Mux | null;
let eventbridge: EventBridgeClient | null;

const handler: SQSHandler = async (event: SQSEvent/*, context: Context*/): Promise<void> => {
    //If there is no mux instance, create a new one. Otherwise, use the existing one.
    mux = getMux(mux);
    //If there is no eventbridge instance, create a new one. Otherwise, use the existing one.
    eventbridge = getEventbridge(eventbridge);
    if (!mux) {
        console.info("mux is null. Nothing processed.")
    }
    else if (!eventbridge) {
        console.info("Eventbridge is null. Nothing processed.")
    }
    else {
        //loop through each message from the SQSEvent
        for (const message of event.Records) {
            //Ensure the message comes from Mux.
            const verified = await verifyMessageAsync(message, mux);
            if (!verified) {
                console.log("Message not from Mux")
            } else {
                console.log("Mux verification successful. Publishing message to Eventbridge.")
                const payload = JSON.parse(message.body);
                const eventType = payload.type
                console.log("eventType ", eventType)
                const params = {
                    Entries: [
                        {
                            Detail: JSON.stringify({
                                "metadata": {
                                    // enriched flag set
                                    "enrich": true,
                                },
                                "data": message.body,
                                "muxSignature": message.messageAttributes.muxSignature.stringValue
                            }),
                            DetailType: eventType, //process.env.DETAIL_TYPE,
                            EventBusName: process.env.MUX_EVENT_BUS,
                            Source: process.env.MUX_LAMBDA_EVENT_SOURCE,
                            Time: new Date
                        }
                    ]
                }
                //Send the events to eventbridge
                const result = await eventbridge.send(new PutEventsCommand(params));
                console.log(result)
            }
        }
    }
};

export { handler };