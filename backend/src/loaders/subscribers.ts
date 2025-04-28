import handleInviteCreated from "../subscribers/invite-created";

// This file simply imports the subscribers.
// Medusa's loader mechanism should pick them up from here
// if automatic discovery from the subscribers/ directory is not working.

export default async function () {
  // We might not need to explicitly do anything here,
  // the import statement itself might be enough for the build process.
  // If needed later, manual registration logic could be added.
  console.log("Loading custom subscribers..."); // Add a log for verification
} 