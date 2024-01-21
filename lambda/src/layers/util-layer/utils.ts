import Mux from '@mux/mux-node';
import { SQSRecord } from "aws-lambda";
import { EventBridgeClient, PutEventsCommand } from "@aws-sdk/client-eventbridge"

const getEventbridge = (eventbridge: EventBridgeClient | null): EventBridgeClient | null => {
    //if no eventbridge instance, instantiate a new eventbridge instance. Otherwise, return the existing eventbridge instance without
    //instantiating a new one.
    if (!eventbridge) {
        eventbridge = new EventBridgeClient({});
        // console.log("Instantiated a new Eventbridge object.")
    } else {
        // console.log("Found an existing Eventbridge object instance.")
    }
    return eventbridge;
};

const getMux = (mux: Mux | null): Mux | null => {
    //if no mux instance, instantiate a new mux instance. Otherwise, return the existing mux instance without
    //instantiating a new one.
    if (!mux) {
        // assume process.env.MUX_TOKEN_ID and process.env.MUX_TOKEN_SECRET contain your credentials
        mux = new Mux();
        // console.log("Instantiated a new Mux object.")
    } else {
        // console.log("Found an existing Mux object instance.")
    }
    return mux;
};

//Ensures the message is a genuine mux message
async function verifyMessageAsync(message: SQSRecord, mux: Mux | null): Promise<boolean> {
    const payload = message.body;
    const sig = message.messageAttributes.muxSignature.stringValue
    console.log('message attributes ', message.messageAttributes);
    console.log('mux signature ', sig);
    console.log(`Processed message ${payload}`);
    let event;
    try {
        //Use Mux's constructEvent method to verify the message
        event = Mux?.Webhooks.verifyHeader(payload, sig!, process.env.MUX_WEBHOOK_SIGNING_SECRET!);
    } catch (err: unknown) {
        if (err instanceof Error) {
            console.error(`Webhook Error: ${err.message}`);
        }
        return false
    }
    return true
}

export { getEventbridge, getMux, verifyMessageAsync }