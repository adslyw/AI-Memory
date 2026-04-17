from django.contrib import admin, messages
from django.urls import path
from django.shortcuts import redirect
from django.utils.html import format_html

from adminsortable2.admin import (
    SortableAdminBase,
    SortableInlineAdminMixin,
)

from .models import AppleSite, AppleCategory
from applecms.services.category_sync import AppleCategorySyncService


class AppleCategoryInline(SortableInlineAdminMixin, admin.TabularInline):
    model = AppleCategory
    extra = 0

    fields = (
        "type_id",
        "type_name",
        "order",
        "enabled",
    )


@admin.register(AppleSite)
class AppleSiteAdmin(SortableAdminBase, admin.ModelAdmin):
    list_display = (
        "name",
        "key",
        "is_adult",
        "enabled",
        "sync_button",
    )

    list_filter = (
        "enabled",
        "is_adult",
    )

    search_fields = (
        "name",
        "key",
    )

    readonly_fields = (
        "created_at",
    )

    fieldsets = (
        ("基本信息", {
            "fields": (
                "name",
                "key",
                "api_base",
                "enabled",
            )
        }),
        ("TVBox 能力", {
            "fields": (
                "searchable",
                "quick_search",
                "filterable",
                "timeout",
            )
        }),
        ("分级控制", {
            "fields": (
                "is_adult",
            )
        }),
        ("时间信息", {
            "fields": (
                "created_at",
            )
        }),
    )

    inlines = [AppleCategoryInline]

    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path(
                "<int:site_id>/sync-categories/",
                self.admin_site.admin_view(self.sync_categories),
                name="applecms_sync_categories",
            ),
        ]
        return custom_urls + urls

    def get_actions(self, request):
        actions = super().get_actions(request)
        if "sync_all_categories" not in actions:
            actions["sync_all_categories"] = (
                self.__class__.sync_all_categories_action,
                "sync_all_categories",
                "同步所有站点的分类（批量操作）",
            )
        return actions

    def sync_categories(self, request, site_id):
        site = AppleSite.objects.get(id=site_id)
        try:
            result = AppleCategorySyncService.sync(site)
            messages.success(request, f"分类同步完成：{result}")
        except Exception as e:
            messages.error(request, f"分类同步失败：{e}")
        return redirect(f"/admin/applecms/applesite/{site_id}/change/")

    @staticmethod
    def sync_all_categories_action(modeladmin, request, queryset):
        """批量操作：同步所有站点的分类"""
        sites = AppleSite.objects.filter(enabled=True)
        if not sites.exists():
            messages.warning(request, "没有找到启用的站点")
            return
        success_count = 0
        error_count = 0
        for site in sites:
            try:
                result = AppleCategorySyncService.sync(site)
                success_count += 1
            except Exception as e:
                error_count += 1
                messages.error(request, f"站点 '{site.name}' 同步失败：{e}")
        if success_count > 0:
            messages.success(
                request,
                f"批量同步完成：成功 {success_count} 个站点，失败 {error_count} 个站点",
            )

    def sync_button(self, obj):
        return format_html(
            '<a class="button" href="{}">同步分类</a>',
            f"{obj.id}/sync-categories/",
        )
    sync_button.short_description = "分类同步"

    def changelist_view(self, request, extra_context=None):
        return super().changelist_view(request, extra_context=extra_context)
