#!/usr/bin/env python3
"""
MCP Server for Vault Access
Provides MCP tools for LLM agents to interact with the journal vault
"""

import asyncio
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional
import mimetypes

# Add the mcp package to the path
sys.path.append('/usr/local/lib/python3.11/site-packages')

try:
    from mcp.server import Server
    from mcp.server.models import InitializationOptions
    from mcp.server.stdio import stdio_server
    from mcp.types import (
        CallToolRequest,
        CallToolResult,
        ListToolsRequest,
        ListToolsResult,
        Tool,
        TextContent,
        ImageContent,
        EmbeddedResource,
    )
except ImportError:
    print("MCP package not found. Installing...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "mcp"])
    from mcp.server import Server
    from mcp.server.models import InitializationOptions
    from mcp.server.stdio import stdio_server
    from mcp.types import (
        CallToolRequest,
        CallToolResult,
        ListToolsRequest,
        ListToolsResult,
        Tool,
        TextContent,
        ImageContent,
        EmbeddedResource,
    )

# Configuration
VAULT_PATH = os.environ.get('VAULT_PATH', '/journals')
ALLOWED_EXTENSIONS = {'.md', '.markdown', '.txt', '.json'}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB limit

class VaultMCPServer:
    def __init__(self):
        self.server = Server("vault-mcp-server")
        self.vault_path = Path(VAULT_PATH)
        self.setup_handlers()
    
    def setup_handlers(self):
        """Set up MCP server handlers"""
        
        @self.server.list_tools()
        async def handle_list_tools() -> ListToolsResult:
            """List available vault tools"""
            tools = [
                Tool(
                    name="list_journal_files",
                    description="List all journal files in the vault",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "pattern": {
                                "type": "string",
                                "description": "Optional file pattern to filter results (e.g., '*.md', '2024-*')",
                                "default": "*"
                            },
                            "recursive": {
                                "type": "boolean",
                                "description": "Whether to search subdirectories recursively",
                                "default": True
                            }
                        }
                    }
                ),
                Tool(
                    name="read_journal_file",
                    description="Read the contents of a specific journal file",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "file_path": {
                                "type": "string",
                                "description": "Path to the journal file relative to vault root"
                            }
                        },
                        "required": ["file_path"]
                    }
                ),
                Tool(
                    name="search_journal_content",
                    description="Search for text content across all journal files",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "query": {
                                "type": "string",
                                "description": "Text to search for in journal files"
                            },
                            "case_sensitive": {
                                "type": "boolean",
                                "description": "Whether search should be case sensitive",
                                "default": False
                            },
                            "file_pattern": {
                                "type": "string",
                                "description": "Optional file pattern to limit search scope",
                                "default": "*.md"
                            }
                        },
                        "required": ["query"]
                    }
                ),
                Tool(
                    name="get_journal_metadata",
                    description="Get metadata about a journal file (size, modified date, etc.)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "file_path": {
                                "type": "string",
                                "description": "Path to the journal file relative to vault root"
                            }
                        },
                        "required": ["file_path"]
                    }
                ),
                Tool(
                    name="write_journal_file",
                    description="Write content to a journal file (markdown files only)",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "file_path": {
                                "type": "string",
                                "description": "Path to the journal file relative to vault root"
                            },
                            "content": {
                                "type": "string",
                                "description": "Content to write to the file"
                            },
                            "append": {
                                "type": "boolean",
                                "description": "Whether to append to existing file or overwrite",
                                "default": False
                            }
                        },
                        "required": ["file_path", "content"]
                    }
                ),
                Tool(
                    name="create_journal_entry",
                    description="Create a new journal entry with timestamp",
                    inputSchema={
                        "type": "object",
                        "properties": {
                            "title": {
                                "type": "string",
                                "description": "Title for the journal entry"
                            },
                            "content": {
                                "type": "string",
                                "description": "Content of the journal entry"
                            },
                            "date": {
                                "type": "string",
                                "description": "Date for the entry (YYYY-MM-DD format, defaults to today)",
                                "default": None
                            },
                            "category": {
                                "type": "string",
                                "description": "Optional category/folder for the entry",
                                "default": None
                            }
                        },
                        "required": ["title", "content"]
                    }
                )
            ]
            return ListToolsResult(tools=tools)
        
        @self.server.call_tool()
        async def handle_call_tool(name: str, arguments: Dict[str, Any]) -> CallToolResult:
            """Handle tool calls"""
            try:
                if name == "list_journal_files":
                    return await self.list_journal_files(arguments)
                elif name == "read_journal_file":
                    return await self.read_journal_file(arguments)
                elif name == "search_journal_content":
                    return await self.search_journal_content(arguments)
                elif name == "get_journal_metadata":
                    return await self.get_journal_metadata(arguments)
                elif name == "write_journal_file":
                    return await self.write_journal_file(arguments)
                elif name == "create_journal_entry":
                    return await self.create_journal_entry(arguments)
                else:
                    return CallToolResult(
                        content=[TextContent(type="text", text=f"Unknown tool: {name}")],
                        isError=True
                    )
            except Exception as e:
                return CallToolResult(
                    content=[TextContent(type="text", text=f"Error: {str(e)}")],
                    isError=True
                )
    
    async def list_journal_files(self, args: Dict[str, Any]) -> CallToolResult:
        """List journal files in the vault"""
        pattern = args.get("pattern", "*")
        recursive = args.get("recursive", True)
        
        try:
            files = []
            if recursive:
                for file_path in self.vault_path.rglob(pattern):
                    if file_path.is_file() and file_path.suffix.lower() in ALLOWED_EXTENSIONS:
                        rel_path = file_path.relative_to(self.vault_path)
                        stat = file_path.stat()
                        files.append({
                            "name": file_path.name,
                            "path": str(rel_path),
                            "size": stat.st_size,
                            "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                            "type": "file"
                        })
            else:
                for file_path in self.vault_path.glob(pattern):
                    if file_path.is_file() and file_path.suffix.lower() in ALLOWED_EXTENSIONS:
                        rel_path = file_path.relative_to(self.vault_path)
                        stat = file_path.stat()
                        files.append({
                            "name": file_path.name,
                            "path": str(rel_path),
                            "size": stat.st_size,
                            "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                            "type": "file"
                        })
            
            result = {
                "files": files,
                "count": len(files),
                "pattern": pattern,
                "recursive": recursive
            }
            
            return CallToolResult(
                content=[TextContent(type="text", text=json.dumps(result, indent=2))]
            )
        except Exception as e:
            return CallToolResult(
                content=[TextContent(type="text", text=f"Error listing files: {str(e)}")],
                isError=True
            )
    
    async def read_journal_file(self, args: Dict[str, Any]) -> CallToolResult:
        """Read a journal file"""
        file_path = args["file_path"]
        
        try:
            full_path = self.vault_path / file_path
            
            # Security check
            if not self.is_safe_path(full_path):
                return CallToolResult(
                    content=[TextContent(type="text", text="Error: Invalid file path")],
                    isError=True
                )
            
            if not full_path.exists():
                return CallToolResult(
                    content=[TextContent(type="text", text=f"File not found: {file_path}")],
                    isError=True
                )
            
            if not full_path.is_file():
                return CallToolResult(
                    content=[TextContent(type="text", text=f"Path is not a file: {file_path}")],
                    isError=True
                )
            
            # Check file size
            if full_path.stat().st_size > MAX_FILE_SIZE:
                return CallToolResult(
                    content=[TextContent(type="text", text=f"File too large: {file_path}")],
                    isError=True
                )
            
            # Read file content
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            result = {
                "file_path": file_path,
                "content": content,
                "size": len(content),
                "encoding": "utf-8"
            }
            
            return CallToolResult(
                content=[TextContent(type="text", text=json.dumps(result, indent=2))]
            )
        except Exception as e:
            return CallToolResult(
                content=[TextContent(type="text", text=f"Error reading file: {str(e)}")],
                isError=True
            )
    
    async def search_journal_content(self, args: Dict[str, Any]) -> CallToolResult:
        """Search for content in journal files"""
        query = args["query"]
        case_sensitive = args.get("case_sensitive", False)
        file_pattern = args.get("file_pattern", "*.md")
        
        try:
            results = []
            search_query = query if case_sensitive else query.lower()
            
            for file_path in self.vault_path.rglob(file_pattern):
                if file_path.is_file() and file_path.suffix.lower() in ALLOWED_EXTENSIONS:
                    try:
                        with open(file_path, 'r', encoding='utf-8') as f:
                            content = f.read()
                        
                        search_content = content if case_sensitive else content.lower()
                        
                        if search_query in search_content:
                            # Find line numbers where query appears
                            lines = content.split('\n')
                            matching_lines = []
                            for i, line in enumerate(lines, 1):
                                search_line = line if case_sensitive else line.lower()
                                if search_query in search_line:
                                    matching_lines.append({
                                        "line_number": i,
                                        "content": line.strip()
                                    })
                            
                            rel_path = file_path.relative_to(self.vault_path)
                            results.append({
                                "file_path": str(rel_path),
                                "matches": len(matching_lines),
                                "matching_lines": matching_lines[:10]  # Limit to first 10 matches
                            })
                    except Exception as e:
                        # Skip files that can't be read
                        continue
            
            result = {
                "query": query,
                "case_sensitive": case_sensitive,
                "file_pattern": file_pattern,
                "results": results,
                "total_matches": sum(r["matches"] for r in results)
            }
            
            return CallToolResult(
                content=[TextContent(type="text", text=json.dumps(result, indent=2))]
            )
        except Exception as e:
            return CallToolResult(
                content=[TextContent(type="text", text=f"Error searching content: {str(e)}")],
                isError=True
            )
    
    async def get_journal_metadata(self, args: Dict[str, Any]) -> CallToolResult:
        """Get metadata about a journal file"""
        file_path = args["file_path"]
        
        try:
            full_path = self.vault_path / file_path
            
            # Security check
            if not self.is_safe_path(full_path):
                return CallToolResult(
                    content=[TextContent(type="text", text="Error: Invalid file path")],
                    isError=True
                )
            
            if not full_path.exists():
                return CallToolResult(
                    content=[TextContent(type="text", text=f"File not found: {file_path}")],
                    isError=True
                )
            
            stat = full_path.stat()
            result = {
                "file_path": file_path,
                "name": full_path.name,
                "size": stat.st_size,
                "modified": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "created": datetime.fromtimestamp(stat.st_ctime).isoformat(),
                "is_file": full_path.is_file(),
                "is_directory": full_path.is_dir(),
                "extension": full_path.suffix,
                "mime_type": mimetypes.guess_type(str(full_path))[0]
            }
            
            return CallToolResult(
                content=[TextContent(type="text", text=json.dumps(result, indent=2))]
            )
        except Exception as e:
            return CallToolResult(
                content=[TextContent(type="text", text=f"Error getting metadata: {str(e)}")],
                isError=True
            )
    
    async def write_journal_file(self, args: Dict[str, Any]) -> CallToolResult:
        """Write content to a journal file (markdown files only)"""
        file_path = args["file_path"]
        content = args["content"]
        append = args.get("append", False)
        
        try:
            full_path = self.vault_path / file_path
            
            # Security check
            if not self.is_safe_path(full_path):
                return CallToolResult(
                    content=[TextContent(type="text", text="Error: Invalid file path")],
                    isError=True
                )
            
            # Only allow markdown files for writing
            if full_path.suffix.lower() not in {'.md', '.markdown'}:
                return CallToolResult(
                    content=[TextContent(type="text", text="Error: Only markdown files can be written")],
                    isError=True
                )
            
            # Create directory if it doesn't exist
            full_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write content
            mode = 'a' if append else 'w'
            with open(full_path, mode, encoding='utf-8') as f:
                f.write(content)
            
            result = {
                "file_path": file_path,
                "operation": "append" if append else "write",
                "bytes_written": len(content.encode('utf-8')),
                "success": True
            }
            
            return CallToolResult(
                content=[TextContent(type="text", text=json.dumps(result, indent=2))]
            )
        except Exception as e:
            return CallToolResult(
                content=[TextContent(type="text", text=f"Error writing file: {str(e)}")],
                isError=True
            )
    
    async def create_journal_entry(self, args: Dict[str, Any]) -> CallToolResult:
        """Create a new journal entry with timestamp"""
        title = args["title"]
        content = args["content"]
        date = args.get("date")
        category = args.get("category")
        
        try:
            # Use provided date or today
            if date:
                entry_date = datetime.strptime(date, "%Y-%m-%d")
            else:
                entry_date = datetime.now()
            
            # Create filename
            safe_title = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_')).rstrip()
            safe_title = safe_title.replace(' ', '-')
            filename = f"{entry_date.strftime('%Y-%m-%d')}-{safe_title}.md"
            
            # Determine file path
            if category:
                file_path = Path(category) / filename
            else:
                file_path = Path(filename)
            
            full_path = self.vault_path / file_path
            
            # Security check
            if not self.is_safe_path(full_path):
                return CallToolResult(
                    content=[TextContent(type="text", text="Error: Invalid file path")],
                    isError=True
                )
            
            # Create directory if it doesn't exist
            full_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Create journal entry content
            entry_content = f"""# {title}

**Date:** {entry_date.strftime('%Y-%m-%d %H:%M:%S')}
**Category:** {category or 'General'}

---

{content}

---
*Created by AI Assistant*
"""
            
            # Write file
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write(entry_content)
            
            result = {
                "file_path": str(file_path),
                "title": title,
                "date": entry_date.isoformat(),
                "category": category,
                "bytes_written": len(entry_content.encode('utf-8')),
                "success": True
            }
            
            return CallToolResult(
                content=[TextContent(type="text", text=json.dumps(result, indent=2))]
            )
        except Exception as e:
            return CallToolResult(
                content=[TextContent(type="text", text=f"Error creating journal entry: {str(e)}")],
                isError=True
            )
    
    def is_safe_path(self, path: Path) -> bool:
        """Check if path is safe (within vault directory)"""
        try:
            path.resolve().relative_to(self.vault_path.resolve())
            return True
        except ValueError:
            return False

async def main():
    """Main entry point"""
    server_instance = VaultMCPServer()
    
    # Initialize the server
    init_options = InitializationOptions(
        server_name="vault-mcp-server",
        server_version="1.0.0",
        capabilities={}
    )
    
    async with stdio_server() as (read_stream, write_stream):
        await server_instance.server.run(
            read_stream,
            write_stream,
            init_options
        )

if __name__ == "__main__":
    asyncio.run(main())

