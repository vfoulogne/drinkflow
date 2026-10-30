-- Correctif : sans parenthèses, « a || b -> 'items' » se lit « (a || b) -> 'items' »,
-- ce qui ne gardait que le dernier article coché. On fusionne maintenant les deux listes.
create or replace function public.repas_merge_items(p_path text, p_items jsonb)
returns void
language sql
security invoker
set search_path = public
as $$
  insert into repas_docs (path, data, updated_at)
  values (p_path, jsonb_build_object('items', p_items), now())
  on conflict (path) do update
    set data = jsonb_set(
          coalesce(repas_docs.data, '{}'::jsonb),
          '{items}',
          coalesce(repas_docs.data->'items', '{}'::jsonb) || coalesce(excluded.data->'items', '{}'::jsonb)
        ),
        updated_at = now();
$$;

revoke execute on function public.repas_merge_items(text, jsonb) from public, anon;
grant execute on function public.repas_merge_items(text, jsonb) to authenticated;
