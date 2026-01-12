# How to Use Links in Cortex

## Overview
Cortex has **two types of links** between facts:

1. **Direct Links (Manual)** - Created explicitly by you using `[[wiki syntax]]`
2. **Semantic Links (AI)** - Automatically discovered based on content similarity

---

## 1. Direct Links (Manual)

### How to Create Direct Links

**Step 1: Create two related facts**

For example:
- Fact A: "Reinforcement learning uses rewards and penalties to train agents"
- Fact B: "Q-learning is a popular algorithm in reinforcement learning"

**Step 2: Add [[link syntax]] to create the connection**

Edit Fact B to include a link:
```
Q-learning is a popular algorithm in [[reinforcement learning]]
```

**How it works:**
- The text inside `[[...]]` is matched against the content of other facts
- If "reinforcement learning" appears in Fact A's content, a link is created
- The link is **bidirectional** - you can navigate both ways

**Step 3: Click the link to navigate**

In the fact detail view, `[[reinforcement learning]]` will appear as a highlighted, clickable pill. Clicking it navigates to Fact A.

### Tips for Direct Links

- **Match existing content**: The link text must appear in another fact's content
- **Be specific**: Use distinctive phrases that uniquely identify the target fact
- **Case insensitive**: `[[Machine Learning]]` matches "machine learning"
- **Partial matching**: The system will find the best match if exact text isn't found

### Example Direct Link Patterns

```
✅ GOOD:
"[[Pythagorean theorem]] applies to right triangles"
→ Links to: "The Pythagorean theorem states a² + b² = c²"

✅ GOOD:
"[[neural networks]] use backpropagation"
→ Links to: "Neural networks are computational models..."

❌ WON'T WORK:
"[[some concept]]" when no other fact contains "some concept"
```

---

## 2. Semantic Links (AI-Powered)

### Prerequisites

**You need an OpenAI API key** to use semantic links.

**Step 1: Configure API Key**
1. Go to **Settings** (gear icon)
2. Scroll to **API Configuration**
3. Enter your OpenAI API key (starts with `sk-...`)
4. Click **Save**

**Step 2: Generate Embeddings**

For each fact you want to connect semantically:
1. Open the fact in detail view
2. If you see a blue banner saying "Generate embedding to find related facts", click **Generate**
3. Wait 1-2 seconds for the embedding to be created
4. The fact can now be semantically linked

### How Semantic Links Work

1. **Embeddings are vector representations** of fact content
2. The system calculates **cosine similarity** between all fact pairs
3. If similarity ≥ 75%, a semantic link is drawn in the graph view
4. **Strength varies**: 75% = weak connection, 95% = very strong connection

### Viewing Semantic Links

**In the Graph View:**
- Toggle semantic links on/off with the link icon in the app bar
- Semantic edges appear as **dashed, thinner lines**
- Manual links appear as **solid, thicker lines**

**In the Fact Detail View:**
- The "Related Facts" panel shows semantically similar facts
- Each related fact shows its similarity percentage

---

## 3. Check Connection Strength Between Two Facts

**New Feature!** You can now check the similarity between any two facts.

**Step 1: Open a fact** that has an embedding generated

**Step 2: Click the compare icon** (⇄) in the app bar

**Step 3: Search and select** another fact to compare

**Step 4: View the results:**
- Similarity percentage (0-100%)
- Visual progress bar
- Description (e.g., "Very similar - strong semantic connection")
- Preview of the compared fact

### Similarity Scale

| Percentage | Description | Meaning |
|------------|-------------|---------|
| 90-100% | Extremely similar | Nearly identical concepts |
| 75-89% | Very similar | Strong semantic connection (shown in graph) |
| 60-74% | Moderately similar | Related topics |
| 40-59% | Somewhat similar | Loose connection |
| 0-39% | Not similar | Different topics |

---

## 4. Troubleshooting

### "Why aren't my two reinforcement learning facts connected?"

**Check these things:**

1. **Do both facts have embeddings?**
   - Open each fact and look for "Embedding: Generated" in the metadata
   - If not, click the "Generate" button in the blue banner

2. **Is the similarity below 75%?**
   - Use the "Check similarity" feature (⇄ icon) to see the exact percentage
   - If it's below 75%, they won't show in the graph view
   - You can still see them in the "Related Facts" panel (threshold: 60%)

3. **Is semantic view enabled in the graph?**
   - In the graph view, check if the link icon is enabled (not crossed out)
   - Click it to toggle semantic edges on

4. **Do you have an OpenAI API key configured?**
   - Go to Settings → API Configuration
   - You should see a green "Configured" badge

### "My [[link]] isn't working"

**Common issues:**

1. **No matching fact**
   - The text inside `[[...]]` must exist in another fact
   - Check spelling and try using a longer, more unique phrase

2. **Syntax error**
   - Make sure you're using double brackets: `[[text]]`
   - Not single brackets: `[text]`

3. **Link not clickable**
   - Links only work in the fact detail view
   - They appear as highlighted pills with a border

---

## 5. Best Practices

### For Direct Links:
- Use `[[concept name]]` for key terms that appear in multiple facts
- Create a "hub fact" for major topics and link to it from related facts
- Be consistent with terminology across facts

### For Semantic Links:
- Generate embeddings for all facts in a topic area
- Review the "Related Facts" panel to discover unexpected connections
- Use the similarity checker to verify that facts are properly related
- Regenerate embeddings if you significantly edit a fact's content

---

## 6. API Costs

**OpenAI Embedding API Pricing** (as of 2024):
- Model: `text-embedding-3-small`
- Cost: ~$0.00002 per 1,000 tokens
- Average fact: ~50-100 tokens
- **100 facts ≈ $0.001 (one-tenth of a cent)**

Embeddings are generated once per fact and stored locally, so you only pay once.

---

## 7. Example Workflow

**Building a knowledge base on "Machine Learning":**

1. Create facts without worrying about links:
   ```
   - "Supervised learning uses labeled data"
   - "Neural networks consist of layers of neurons"
   - "Backpropagation updates network weights"
   - "Gradient descent minimizes loss functions"
   ```

2. Generate embeddings for all facts (Settings → generate for each)

3. Check the graph view to see automatic semantic connections

4. Add manual links where you want explicit relationships:
   ```
   "[[Neural networks]] use [[backpropagation]] to learn"
   "[[Gradient descent]] is used in [[backpropagation]]"
   ```

5. Use the similarity checker to verify connections and discover insights

---

## Need Help?

- Open an issue at: https://github.com/saumyamishra654/cortex
- The direct link feature is implemented in `lib/widgets/linked_text.dart`
- Semantic links are in `lib/services/embedding_service.dart`
