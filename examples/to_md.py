#!/usr/bin/env python3
"""
Conversation Log to Markdown Formatter

This script transforms a conversation log into markdown format with:
1. Everything in monospace
2. Time/author (HH:MM Name:) in bold
3. Vim folds ({{{ ... }}}) converted to collapsible <details> sections

Usage:
    python log_to_markdown.py input_file.txt
    # Output will be saved to input_file.md
"""

import sys
import re
import os.path

def transform_to_markdown(log_content):
    """
    Transform a conversation log to markdown with specified formatting.
    
    Args:
        log_content (str): The content of the log file
        
    Returns:
        str: The transformed markdown content
    """
    lines = log_content.strip().split('\n')
    markdown = ["```"]
    
    in_fold = False
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check for time/author pattern (HH:MM Name:)
        time_author_match = re.match(r'^(\d{2}:\d{2} [^:]+:)(.*)', line)
        if time_author_match:
            time_author, rest_of_line = time_author_match.groups()
            line = f"**{time_author}**{rest_of_line}"
        
        # Check for fold start
        if "{{{" in line:
            in_fold = True
            
            # Close monospace temporarily
            markdown.append("```")
            
            # Extract summary if available
            summary_match = re.search(r'{{{(.*)}', line)
            summary = summary_match.group(1).strip() if summary_match else "Details"
            
            # Open details tag with summary
            markdown.append("<details>")
            markdown.append(f"<summary>{summary}</summary>")
            markdown.append("")
            markdown.append("```")
            
            # Skip the fold marker line if it only contains the marker
            if line.strip() == "{{{":
                i += 1
                continue
            
            # Otherwise include the actual content from this line (without the marker)
            content = re.sub(r'{{{.*', '', line).strip()
            if content:
                markdown.append(content)
        
        # Check for fold end
        elif "}}}" in line and in_fold:
            # Remove the fold end marker and add remaining content if any
            content = re.sub(r'}}}.*', '', line).strip()
            if content:
                markdown.append(content)
            
            # Close monospace and details
            markdown.append("```")
            markdown.append("</details>")
            markdown.append("")
            markdown.append("```")
            
            in_fold = False
        
        # Add normal lines
        else:
            markdown.append(line)
        
        i += 1
    
    # Close final monospace block if needed
    if not in_fold:
        markdown.append("```")
    
    return '\n'.join(markdown)

def main():
    """
    Process the input file and generate markdown output.
    """
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} input_file.txt")
        sys.exit(1)
    
    input_filename = sys.argv[1]
    
    # Generate output filename (replace extension with .md or add .md)
    base_name, ext = os.path.splitext(input_filename)
    output_filename = f"{base_name}.md"
    
    try:
        # Read input file
        with open(input_filename, 'r', encoding='utf-8') as f:
            log_content = f.read()
        
        # Transform content
        markdown_content = transform_to_markdown(log_content)
        
        # Write output file
        with open(output_filename, 'w', encoding='utf-8') as f:
            f.write(markdown_content)
        
        print(f"Successfully converted {input_filename} to {output_filename}")
    
    except FileNotFoundError:
        print(f"Error: File '{input_filename}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
