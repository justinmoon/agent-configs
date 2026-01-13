import { tool } from "@opencode-ai/plugin";
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";

export default tool({
	description:
		"PREFERRED for `.env*` files: read dotenv content. Use this instead of the generic `read` tool when accessing `.env`, `.env.dev`, `.env.test`, `.env.prod`, etc. (Some sandboxes block dotenv reads via normal file tools.)",
	args: {
		filePath: tool.schema
			.string()
			.describe("Absolute path to the dotenv file (e.g. /abs/path/.env.dev)"),
	},
	async execute(args) {
		const { filePath } = args;

		// Validate it's a dotenv-style file
		const basename = filePath.split("/").pop() || "";
		if (!basename.startsWith(".env") && !basename.includes(".env")) {
			throw new Error(
				`File "${basename}" does not appear to be a dotenv file. Expected filename starting with .env or containing .env`,
			);
		}

		if (!existsSync(filePath)) {
			throw new Error(`File not found: ${filePath}`);
		}

		const content = await readFile(filePath, "utf-8");
		return content;
	},
});
