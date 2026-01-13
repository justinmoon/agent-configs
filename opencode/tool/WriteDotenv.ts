import { tool } from "@opencode-ai/plugin";
import { writeFile } from "node:fs/promises";

export default tool({
	description:
		"PREFERRED for `.env*` files: write/update dotenv content. Use this instead of the generic `write`/`edit` tools when changing `.env`, `.env.dev`, `.env.test`, `.env.prod`, etc.",
	args: {
		filePath: tool.schema
			.string()
			.describe("Absolute path to the dotenv file (e.g. /abs/path/.env.prod)"),
		content: tool.schema
			.string()
			.describe("The full content to write to the file"),
	},
	async execute(args) {
		const { filePath, content } = args;

		// Validate it's a dotenv-style file
		const basename = filePath.split("/").pop() || "";
		if (!basename.startsWith(".env") && !basename.includes(".env")) {
			throw new Error(
				`File "${basename}" does not appear to be a dotenv file. Expected filename starting with .env or containing .env`,
			);
		}

		await writeFile(filePath, content, "utf-8");
		return `Successfully wrote ${content.length} bytes to ${filePath}`;
	},
});
