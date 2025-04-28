import {
  type SubscriberConfig,
  // type SubscriberArgs, // We might not need this specific type if using the older pattern
  MedusaContainer, // Import container type directly
} from "@medusajs/medusa"
import { Resend } from "resend"
import { Logger } from "@medusajs/framework/types" // Import Logger type

type InviteCreatedEvent = {
  id: string;
  user_email: string;
  token: string;
}

// Adjusted function signature based on common Medusa v1 subscriber patterns
export default async function handleInviteCreated(
  eventData: InviteCreatedEvent, // Event payload as first argument
  container: MedusaContainer // Container as second argument (or injected dependencies object)
) {
  const logger = container.resolve<Logger>("logger") // Resolve logger correctly
  const resend = new Resend(process.env.RESEND_API_KEY)

  // Basic check for necessary data and config
  if (!process.env.RESEND_API_KEY) {
    logger.error("Resend API Key not found in environment variables.")
    return
  }
  if (!process.env.RESEND_FROM) {
    logger.error("Resend From address not found in environment variables.")
    return
  }
  // Access data directly from the first argument
  if (!eventData.user_email || !eventData.token) {
    logger.error("Invite created event is missing user_email or token.")
    return
  }

  // Construct the invite URL (Adjust frontend URL as needed)
  const inviteUrl = `https://admin-staging.flowdose.xyz/invite?token=${eventData.token}`;

  logger.info(`Handling invite created/resent for ${eventData.user_email}`);

  try {
    await resend.emails.send({
      from: process.env.RESEND_FROM,
      to: eventData.user_email,
      subject: "You've been invited to join FlowDose",
      html: `<p>Hello,</p><p>You have been invited to create a user on FlowDose.</p><p>Click the link below to accept the invite and set your password:</p><p><a href="${inviteUrl}">Accept Invite</a></p><p>If you did not expect this invitation, you can ignore this email.</p>`,
      // You can add a text version as well
      // text: `...`,
    });
    logger.info(`Invite email sent successfully to ${eventData.user_email}`);
  } catch (error) {
    logger.error(`Error sending invite email to ${eventData.user_email}:`, error)
  }
}

// Subscribe to the invite.created event
export const config: SubscriberConfig = {
  event: "invite.created",
  context: {
    subscriberId: "invite-created-handler",
  },
} 