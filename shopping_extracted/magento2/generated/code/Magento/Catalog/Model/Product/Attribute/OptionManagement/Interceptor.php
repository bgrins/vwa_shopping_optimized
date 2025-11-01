<?php
namespace Magento\Catalog\Model\Product\Attribute\OptionManagement;

/**
 * Interceptor class for @see \Magento\Catalog\Model\Product\Attribute\OptionManagement
 */
class Interceptor extends \Magento\Catalog\Model\Product\Attribute\OptionManagement implements \Magento\Framework\Interception\InterceptorInterface
{
    use \Magento\Framework\Interception\Interceptor;

    public function __construct(\Magento\Eav\Api\AttributeOptionManagementInterface $eavOptionManagement, \Magento\Eav\Api\AttributeOptionUpdateInterface $eavOptionUpdate)
    {
        $this->___init();
        parent::__construct($eavOptionManagement, $eavOptionUpdate);
    }

    /**
     * {@inheritdoc}
     */
    public function getItems($attributeCode)
    {
        $pluginInfo = $this->pluginList->getNext($this->subjectType, 'getItems');
        return $pluginInfo ? $this->___callPlugins('getItems', func_get_args(), $pluginInfo) : parent::getItems($attributeCode);
    }

    /**
     * {@inheritdoc}
     */
    public function add($attributeCode, $option)
    {
        $pluginInfo = $this->pluginList->getNext($this->subjectType, 'add');
        return $pluginInfo ? $this->___callPlugins('add', func_get_args(), $pluginInfo) : parent::add($attributeCode, $option);
    }

    /**
     * {@inheritdoc}
     */
    public function update(string $attributeCode, int $optionId, \Magento\Eav\Api\Data\AttributeOptionInterface $option) : bool
    {
        $pluginInfo = $this->pluginList->getNext($this->subjectType, 'update');
        return $pluginInfo ? $this->___callPlugins('update', func_get_args(), $pluginInfo) : parent::update($attributeCode, $optionId, $option);
    }

    /**
     * {@inheritdoc}
     */
    public function delete($attributeCode, $optionId)
    {
        $pluginInfo = $this->pluginList->getNext($this->subjectType, 'delete');
        return $pluginInfo ? $this->___callPlugins('delete', func_get_args(), $pluginInfo) : parent::delete($attributeCode, $optionId);
    }
}
