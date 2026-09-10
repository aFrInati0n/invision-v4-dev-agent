# Differences: Invision Community v4 vs v5

| Feature | Invision Community v4 | Invision Community v5 |
| :--- | :--- | :--- |
| **PHP Version** | PHP 7.4 - PHP 8.1 | PHP 8.2+ |
| **Class Architecture** | Legacy Underscore Prefix (`_Class`) | Native PSR-4 Namespaces |
| **Theme Engine** | PHTML Templates | Modern Template Parser |
| **Hook Implementation** | `_HOOK_CLASS_` Monkey Patching | Modern Events & Attributes |

**Rule for LLM:** Always enforce IC4 structures (`_Class` internal names, `\IPS\Request::i()`, PHTML syntax) when this skill is active.
