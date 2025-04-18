/*
This MCP server code is based on the "HTTP with SSE" example within the Model Context Protocol SDK for TypeScript.
https://github.com/modelcontextprotocol/typescript-sdk?tab=readme-ov-file#http-with-sse

This code is a simple example of how to set up an SSE server using the Model Context Protocol (MCP) SDK.
It uses the `SSEServerTransport` class to handle server-sent events (SSE) and allows multiple clients to connect simultaneously.

This example was made runnable by Powergentic.ai and Chris Pietschmann (https://pietschsoft.com)
*/
import express, { Request, Response } from "express";
import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { z } from "zod";

const PORT = process.env.PORT || 3001;

// ##################################################
// This is a simple example of how to set up an SSE server using the Model Context Protocol (MCP) SDK.

// ✅ Define the server
// The server name and version are used to identify the server in the MCP protocol.
const server = new McpServer({
  name: "example-server",
  version: "1.0.0"
});


// ✅ Define the Resources
server.resource(
  "echo",
  new ResourceTemplate("echo://{message}", {
    list: undefined,
  }),
  {
    description: "Echoes the message back to the user."
  },
  async (uri, { message }) => ({
    contents: [{
      uri: uri.href,
      text: `Resource echo: ${message}`
    }]
  })
);

// ✅ Define the Tools
server.tool(
  "echo",
  "Echoes the message back to the user.",
  { message: z.string() },
  async ({ message }) => ({
    content: [{ type: "text", text: `Tool echo: ${message}` }]
  })
);

// ✅ Define the Prompts
server.prompt(
  "echo",
  "Echoes the message back to the user.",
  { message: z.string() },
  ({ message }) => ({
    messages: [{
      role: "user",
      content: {
        type: "text",
        text: `Please process this message: ${message}`
      }
    }]
  })
);

// ##################################################
// Create an Express server
const app = express();

// Add middleware to serve static files from the 'public' directory
app.use(express.static("public"));

// to support multiple simultaneous connections we have a lookup object from
// sessionId to transport
const transports: {[sessionId: string]: SSEServerTransport} = {};

app.get("/sse", async (_: Request, res: Response) => {
  const transport = new SSEServerTransport('/messages', res);
  transports[transport.sessionId] = transport;
  res.on("close", () => {
    delete transports[transport.sessionId];
  });
  try {
    await server.connect(transport);
  } catch (error: any) {
    console.error("Error connecting transport:", error);
    res.status(500).send("Error connecting transport");
  }
});

app.post("/messages", async (req: Request, res: Response) => {
  const sessionId = req.query.sessionId as string;
  const transport = transports[sessionId];
  if (transport) {
    await transport.handlePostMessage(req, res);
  } else {
    console.error("No transport found for sessionId:", sessionId);
    res.status(400).send('No transport found for sessionId');
  }
});

app.post("/message", async (req: Request, res: Response) => {
  const sessionId = req.query.sessionId as string;
  const transport = transports[sessionId];
  if (transport) {
    await transport.handlePostMessage(req, res);
  } else {
    console.error("No transport found for sessionId:", sessionId);
    res.status(400).send('No transport found for sessionId');
  }
});


app.listen(PORT);
console.log(`Server started on http://localhost:${PORT}  🚀`);
console.log(`Connect to SSE stream at http://localhost:${PORT}/sse`);
console.log(`Press Ctrl+C to stop the server`);
