import {
  type SubscriberConfig,
  MedusaContainer,
} from "@medusajs/medusa"
import { ModuleRegistrationName } from "@medusajs/framework/utils"
import { IUserModuleService } from "@medusajs/types"
import { Resend } from "resend"
import { Logger } from "@medusajs/framework/types"

// Define the expected structure for the data property
type InviteCreatedEventData = {
  id: string;
}

export default async function handleInviteCreated(
  // Use generic args based on observed structure: [{ event: {data: {id}}, container }]
  ...args: any[]
) {
  // Extract container and event data from the first argument
  const firstArg = args?.[0];
  const container = firstArg?.container;
  const eventData = firstArg?.event?.data;
  const eventName = firstArg?.event?.name;

  if (!container) {
    console.error("Could not extract container from subscriber arguments.");
    console.error("Received args:", JSON.stringify(args));
    return;
  }

  const logger = container.resolve("logger");
  logger.info(`Handling event: ${eventName}. Raw args: ${JSON.stringify(args)}`);

  if (!eventData) {
    logger.error(`Event data is missing in args[0].event.data`);
    return;
  }

  const inviteId = eventData.id;
  if (!inviteId) {
    logger.error("Invite created event data is missing id.");
    return;
  }

  // Rest of the logic remains the same, using inviteId
  const resend = new Resend(process.env.RESEND_API_KEY)

  // Basic check for necessary config
  if (!process.env.RESEND_API_KEY) {
    logger.error("Resend API Key not found in environment variables.")
    return
  }
  if (!process.env.RESEND_FROM) {
    logger.error("Resend From address not found in environment variables.")
    return
  }

  // Use User Module instead of inviteService
  let userModuleService: IUserModuleService; 
  try {
    userModuleService = container.resolve(ModuleRegistrationName.USER);
  } catch (error) {
    logger.error("Could not resolve user module service:", error)
    return
  }

  // Get invite from the user module
  let invite: any;
  try {
    // The result is an array of invites, not an object with invites property
    const invites = await userModuleService.listInvites({
      id: inviteId
    });
    
    if (invites.length === 0) {
      logger.error(`No invite found with id ${inviteId}`);
      return;
    }
    
    invite = invites[0];
    
    // Log the invite structure to see what fields are actually available
    logger.info(`Invite structure: ${JSON.stringify(invite)}`);
  } catch (error) {
    logger.error(`Failed to retrieve invite with id ${inviteId}:`, error)
    return
  }

  // In Medusa 2.x, the field names have likely changed 
  // Check if we can find the email and token in the structure
  const userEmail = invite.user_email || invite.email;
  const inviteToken = invite.token;
  
  if (!userEmail || !inviteToken) {
    logger.error(`Retrieved invite data is missing required fields for id ${inviteId}. 
      Available fields: ${Object.keys(invite).join(', ')}`);
    return
  }

  // Construct the invite URL
  const inviteUrl = `https://admin-staging.flowdose.xyz/app/invite?token=${inviteToken}`;

  logger.info(`Handling invite created/resent for ${userEmail}`);

  try {
    await resend.emails.send({
      from: process.env.RESEND_FROM,
      to: userEmail,
      subject: "You've been invited to join FlowDose",
      html: `<p>Hello,</p><p>You have been invited to create a user on FlowDose.</p><p>Click the link below to accept the invite and set your password:</p><p><a href="${inviteUrl}">Accept Invite</a></p><p>If you did not expect this invitation, you can ignore this email.</p>`,
    });
    logger.info(`Invite email sent successfully to ${userEmail}`);
  } catch (error) {
    logger.error(`Error sending invite email to ${userEmail}:`, error)
  }
}

// Subscribe to the invite.created event
export const config: SubscriberConfig = {
  event: "invite.created",
  context: {
    subscriberId: "invite-created-handler",
  },
} 