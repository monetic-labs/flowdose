import {
  type SubscriberConfig,
  // type SubscriberArgs, // We might not need this specific type if using the older pattern
  MedusaContainer, // Import container type directly
  // Assuming InviteService is available, adjust if named differently
  // You might need to import the actual type if available, e.g.:
  // type InviteService = ...
} from "@medusajs/medusa"
import { Resend } from "resend"
import { Logger } from "@medusajs/framework/types" // Import Logger type

// Define the expected structure for the data property
type InviteCreatedEventData = {
  id: string;
}

export default async function handleInviteCreated(
  // Use the standard Medusa v2+ signature with correct type for data
  { data, eventName, container }: { data: InviteCreatedEventData, eventName: string, container: MedusaContainer }
) {
  const logger = container.resolve<Logger>("logger");
  logger.info(`Handling event: ${eventName} with invite ID: ${data?.id}`); // Log event and ID

  // Remove the generic args logic and manual container/data finding

  // Access the id directly from the destructured 'data' object
  const inviteId = data?.id; // Use optional chaining for safety
  if (!inviteId) {
      logger.error("Invite created event is missing id in data object.");
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

  // Fetch invite details using InviteService
  let inviteService: any; // Use 'any' for now, replace with actual type if known
  try {
    // Adjust service name if different (e.g., 'inviteService', 'InviteService')
    inviteService = container.resolve("inviteService")
  } catch (error) {
    logger.error("Could not resolve inviteService:", error)
    return
  }

  let invite: any; // Use 'any' for now, replace with actual Invite type if known
  try {
    // Assuming 'retrieve' is the correct method, adjust if needed
    invite = await inviteService.retrieve(inviteId, {
      // Specify relations if needed, e.g., relations: ['user']
    })
  } catch (error) {
    logger.error(`Failed to retrieve invite with id ${inviteId}:`, error)
    return
  }

  // Check for required fields from the retrieved invite
  if (!invite || !invite.user_email || !invite.token) {
    logger.error(`Retrieved invite data is missing user_email or token for id ${inviteId}.`)
    return
  }

  // Construct the invite URL
  const inviteUrl = `https://admin-staging.flowdose.xyz/invite?token=${invite.token}`;

  logger.info(`Handling invite created/resent for ${invite.user_email}`);

  try {
    await resend.emails.send({
      from: process.env.RESEND_FROM,
      to: invite.user_email,
      subject: "You've been invited to join FlowDose",
      html: `<p>Hello,</p><p>You have been invited to create a user on FlowDose.</p><p>Click the link below to accept the invite and set your password:</p><p><a href="${inviteUrl}">Accept Invite</a></p><p>If you did not expect this invitation, you can ignore this email.</p>`,
    });
    logger.info(`Invite email sent successfully to ${invite.user_email}`);
  } catch (error) {
    logger.error(`Error sending invite email to ${invite.user_email}:`, error)
  }
}

// Subscribe to the invite.created event
export const config: SubscriberConfig = {
  event: "invite.created",
  context: {
    subscriberId: "invite-created-handler",
  },
} 