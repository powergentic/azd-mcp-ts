/*
This MCP server code is based on the "HTTP with SSE" example within the Model Context Protocol SDK for TypeScript.
https://github.com/modelcontextprotocol/typescript-sdk?tab=readme-ov-file#http-with-sse

This code is a simple example of how to set up an SSE server using the Model Context Protocol (MCP) SDK.
It uses the `SSEServerTransport` class to handle server-sent events (SSE) and allows multiple clients to connect simultaneously.

This example was made runnable by Powergentic.ai and Chris Pietschmann (https://pietschsoft.com)
*/
import express, { Request, Response } from "express";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";

const PORT = process.env.PORT || 3001;

const server = new McpServer({
  name: "example-server",
  version: "1.0.0"
});

// ... set up server resources, tools, and prompts ...

const app = express();

// to support multiple simultaneous connections we have a lookup object from
// sessionId to transport
const transports: {[sessionId: string]: SSEServerTransport} = {};

app.get("/sse", async (_: Request, res: Response) => {
  const transport = new SSEServerTransport('/messages', res);
  transports[transport.sessionId] = transport;
  res.on("close", () => {
    delete transports[transport.sessionId];
  });
  await server.connect(transport);
});

app.post("/messages", async (req: Request, res: Response) => {
  const sessionId = req.query.sessionId as string;
  const transport = transports[sessionId];
  if (transport) {
    await transport.handlePostMessage(req, res);
  } else {
    res.status(400).send('No transport found for sessionId');
  }
});

app.listen(PORT);
console.log(`Server started on http://localhost:${PORT}/sse`);
console.log(`Post messages to http://localhost:${PORT}/messages?sessionId=<your-session-id>`);
console.log(`Connect to SSE stream at http://localhost:${PORT}/sse`);
console.log(`Press Ctrl+C to stop the server`);
