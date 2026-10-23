const { Plugin, Modal, Notice, MarkdownView, normalizePath } = require("obsidian");

// 模板放在 vault 根目录；Hugo 那边是 content/templates.md，draft=true 所以不会发布。
const TEMPLATE_PATH = "templates.md";
const POSTS_DIR = "posts";

function pad(n) {
  return String(n).padStart(2, "0");
}

// 生成带时区偏移的本地时间，对应 Hugo front matter 里的 date。
function localISO(date) {
  const d = date || new Date();
  const offset = -d.getTimezoneOffset();
  const sign = offset >= 0 ? "+" : "-";
  const abs = Math.abs(offset);
  return (
    d.getFullYear() +
    "-" + pad(d.getMonth() + 1) +
    "-" + pad(d.getDate()) +
    "T" + pad(d.getHours()) +
    ":" + pad(d.getMinutes()) +
    ":" + pad(d.getSeconds()) +
    sign + pad(Math.floor(abs / 60)) +
    ":" + pad(abs % 60)
  );
}

// 保留中文，去掉文件系统/URL 里的危险字符。
function slugify(title) {
  return (
    title
      .trim()
      .toLowerCase()
      .replace(/[\\/:*?"<>|#^\[\]]/g, "-")
      .replace(/\s+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-+|-+$/g, "")
      .replace(/^\.+|\.+$/g, "") || "untitled"
  );
}

function escapeToml(value) {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

class NewPostModal extends Modal {
  constructor(app, onSubmit) {
    super(app);
    this.onSubmit = onSubmit;
  }

  onOpen() {
    const { contentEl } = this;
    contentEl.createEl("h2", { text: "新建博客文章" });
    contentEl.createEl("p", {
      text: "标题会作为文件夹名和链接。新文章默认是草稿，定稿后把 draft 改成 false。",
      cls: "setting-item-description",
    });

    const input = contentEl.createEl("input", {
      type: "text",
      placeholder: "文章标题",
    });
    input.style.width = "100%";
    input.style.padding = "8px";
    input.style.boxSizing = "border-box";

    const submit = () => {
      const title = input.value.trim();
      if (!title) {
        input.focus();
        return;
      }
      this.close();
      this.onSubmit(title);
    };

    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault();
        submit();
      }
    });

    const footer = contentEl.createDiv({ cls: "modal-button-container" });
    const button = footer.createEl("button", { text: "创建", cls: "mod-cta" });
    button.addEventListener("click", submit);

    window.setTimeout(() => input.focus(), 10);
  }

  onClose() {
    this.contentEl.empty();
  }
}

module.exports = class HugoNewPostPlugin extends Plugin {
  async onload() {
    this.addCommand({
      id: "create-post",
      name: "新建博客文章",
      callback: () => this.openCreateModal(),
    });

    this.addCommand({
      id: "open-template",
      name: "打开文章模板",
      callback: () => this.openTemplate(),
    });

    this.addRibbonIcon("file-plus", "新建博客文章", () => this.openCreateModal());
  }

  openCreateModal() {
    new NewPostModal(this.app, (title) => {
      this.createPost(title).catch((error) => {
        console.error("[hugo-new-post]", error);
        new Notice("创建文章失败：" + (error && error.message ? error.message : error));
      });
    }).open();
  }

  async openTemplate() {
    const file = this.app.vault.getAbstractFileByPath(TEMPLATE_PATH);
    if (!file) {
      new Notice("找不到模板：" + TEMPLATE_PATH);
      return;
    }
    await this.app.workspace.getLeaf(false).openFile(file);
  }

  async createPost(title) {
    const slug = slugify(title);

    // 同名文章已存在时递增后缀，避免覆盖
    let folder = normalizePath(POSTS_DIR + "/" + slug);
    let path = normalizePath(folder + "/index.md");
    let suffix = 2;
    while (this.app.vault.getAbstractFileByPath(path)) {
      folder = normalizePath(POSTS_DIR + "/" + slug + "-" + suffix);
      path = normalizePath(folder + "/index.md");
      suffix += 1;
    }

    let template;
    try {
      template = await this.app.vault.adapter.read(TEMPLATE_PATH);
    } catch (error) {
      throw new Error("读取模板失败：" + TEMPLATE_PATH);
    }

    const content = template
      .replace(/^title\s*=.*$/m, () => 'title = "' + escapeToml(title) + '"')
      .replace(/^date\s*=.*$/m, () => "date = " + localISO())
      .replace(/\{\{title\}\}/g, () => escapeToml(title))
      .replace(/\{\{slug\}\}/g, () => slug);

    if (!this.app.vault.getAbstractFileByPath(folder)) {
      await this.app.vault.createFolder(folder);
    }
    const file = await this.app.vault.create(path, content);
    await this.app.workspace.getLeaf(false).openFile(file);

    // 等编辑器加载完，把光标放到正文末尾
    setTimeout(() => {
      const view = this.app.workspace.getActiveViewOfType(MarkdownView);
      if (view && view.editor) {
        view.editor.setCursor({
          line: Math.max(view.editor.lineCount() - 1, 0),
          ch: 0,
        });
      }
    }, 300);

    new Notice("已创建：" + path);
  }
};
