const fs = require('fs');

const filePath = 'C:/Users/Faisal/.gemini/antigravity/brain/e6c24955-f42c-4f15-b9be-f51cc9b38872/.system_generated/steps/80/content.md';
const html = fs.readFileSync(filePath, 'utf8');

function cleanHTML(htmlStr) {
    const bodyMatch = htmlStr.match(/<body[^>]*>([\s\S]*)<\/body>/i);
    let body = bodyMatch ? bodyMatch[1] : htmlStr;
    
    body = body.replace(/<script[^>]*>([\s\S]*?)<\/script>/gi, '');
    body = body.replace(/<style[^>]*>([\s\S]*?)<\/style>/gi, '');
    body = body.replace(/<\/?[^>]+(>|$)/g, '\n');
    
    // Split lines, trim, and filter out empty ones
    let lines = body.split('\n')
        .map(line => line.replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').trim())
        .filter(line => line.length > 0);
    
    return lines.join('\n');
}

const cleaned = cleanHTML(html);
fs.writeFileSync('C:/Users/Faisal/.gemini/antigravity/scratch/faisal-landing-page/extracted_text.txt', cleaned, 'utf8');
console.log('Done!');
