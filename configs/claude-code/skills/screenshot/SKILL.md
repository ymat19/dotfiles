---
name: screenshot
description: Analyze screenshots taken by the user. Use when the user asks about a screenshot or wants to analyze an image from ~/Pictures/.
---

# Screenshot Analysis Skill

A skill for referencing and analyzing screenshots taken by the user.

## Instructions

When the user asks about a screenshot:

1. **Ask for the screenshot path**
   - Screenshots are saved in `~/Pictures/` with timestamp format
   - Example: `~/Pictures/2025-11-27T14:30:45.png`

2. **Read the image using the Read tool**
   - Carefully examine the image content
   - Check UI elements, error messages, text, and visual indicators

3. **Analyze and respond**
   - Clearly describe what you see
   - Identify issues or areas for improvement
   - Provide specific solutions or suggestions

## Common Use Cases

- Debugging UI bugs or layout issues
- Analyzing error messages
- Understanding application states
- Creating documentation or explanations
