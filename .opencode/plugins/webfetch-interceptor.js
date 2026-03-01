/**
 * WebFetch Interceptor Plugin
 * 
 * Cancels webfetch tool calls and instructs the agent to use agent-browser instead.
 * This enforces the use of the agent-browser CLI for all web interactions.
 */

/**
 * @type {import('@opencode-ai/plugin').Plugin}
 */
export default async function WebFetchInterceptorPlugin({ client }) {
  try {
    await client.app.log({
      body: {
        service: "webfetch-interceptor",
        level: "info",
        message: "WebFetch interceptor plugin loaded - webfetch calls will be redirected to agent-browser",
      },
    })
  } catch {
    // Logging is optional, don't fail if it doesn't work
  }

  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool === "webfetch") {
        const url = output.args?.url || "the requested URL"
        
        throw new Error(
          `WebFetch tool is disabled. Use agent-browser instead for web interactions.\n\n` +
          `## Instructions\n\n` +
          `1. First, load the agent-browser skill:\n` +
          `   \`\`\`\n` +
          `   Use the skill tool to load: skill({ name: "agent-browser" })\n` +
          `   \`\`\`\n\n` +
          `2. Then use the snapshot-ref workflow:\n` +
          `   - \`agent-browser open ${url}\`\n` +
          `   - \`agent-browser snapshot -i\`\n` +
          `   - Interact using refs like \`@e1\`, \`@e2\`\n\n` +
          `## Why agent-browser?\n\n` +
          `- Full browser automation (click, fill, scroll, etc.)\n` +
          `- JavaScript rendering support\n` +
          `- Interactive element detection\n` +
          `- Screenshot capabilities\n` +
          `- Session persistence\n` +
          `- Better for complex web interactions`
        )
      }
    },
  }
}
