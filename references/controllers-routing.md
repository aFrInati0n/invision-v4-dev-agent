# Invision Community 4: Controllers & Form Builders

## Front Controller Template

```php
namespace IPS\your_app\modules\front\general;

class _view extends \IPS\Dispatcher\Controller
{
    public function execute()
    {
        parent::execute();
    }

    protected function manage()
    {
        $form = new \IPS\Helpers\Form();
        $form->add(new \IPS\Helpers\Form\Text('example_title', NULL, TRUE));

        if ($values = $form->values())
        {
            // Process form
        }

        \IPS\Output::i()->output = $form;
    }
}
```
